import UIKit
import SwipeCellKit
import SVProgressHUD
import ChameleonFramework

/* AWS */
import AWSAppSync
import AWSMobileClient

class TodoListViewController: SwipeTableViewController {

    weak var List: Todo?
    var refresing: Bool = false
    fileprivate var nextItem: String = ""
    @IBOutlet weak var searchBar: UISearchBar!
    
    //MARK: - AWS AppSync Variables:
    fileprivate weak var appSyncClient: AWSAppSyncClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appSyncClient   = appDelegate.appSyncClient
        ItemDelegate    = self
        tableView.tag   = 1
        setRefresher()
        if let id = List?.id {
            getListItems(id: id, token: nextItem)
        }
    }
    
    fileprivate func setRefresher() {
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        self.refreshControl?.addTarget(self, action: #selector(refresh), for: UIControl.Event.valueChanged)
    }
    
    @objc func refresh(sender:AnyObject) {
        refresing = true
        if let id = List?.id {
            getListItems(id: id, token: nextItem)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        title = List?.title ?? "Items"
        guard let colorHex = List?.colorHex else {fatalError()}
        updateNaveBar(withHecColor: colorHex)
    }
    
    func updateNaveBar(withHecColor colorHexCode: String){
        guard let navBar   = navigationController?.navigationBar else {fatalError("Navigation controller does not exist.")}
        if let navBarColor = UIColor(hexString: colorHexCode) {
            navBar.barTintColor    = navBarColor
            navBar.tintColor       = ContrastColorOf(navBarColor, returnFlat: true)
            searchBar.barTintColor = navBarColor
            navBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor : ContrastColorOf(navBarColor, returnFlat: true)]
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        updateNaveBar(withHecColor: "00CCFF")
    }
    
    //MAKE - TableView Datasource Method
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return List?.items?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! SwipeTableViewCell
        cell.delegate = self
        if let item = List?.items?[indexPath.row] {
            cell.textLabel?.text = item.title
            cell.accessoryType   = item.done! ? .checkmark : .none
//            cell.backgroundColor = UIColor(hexString: item.colorHex ?? "#F0F8FF")
            let scalar: CGFloat = CGFloat(indexPath.row)/CGFloat(List!.items!.count)
            if let colour = UIColor(hexString: List?.colorHex ?? "#F0F8FF")?.darken(byPercentage:scalar) {
                cell.backgroundColor      = colour
                cell.textLabel?.textColor = ContrastColorOf(colour, returnFlat: true)
            }
        }
        else {
            cell.textLabel?.text = "Add new item!"
        }
        return cell
    }
    
    //MARK - TableView Delegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        SelectItem(index: indexPath.row, appSyncClient: appSyncClient!)
    }
    
    //MARK - Add New Items
    @IBAction func AddButtonPress(_ sender: UIBarButtonItem) {
        
        var textFiel = UITextField()
        let alert    = UIAlertController(title: "Add New Todo Item", message: "", preferredStyle: .alert)
        alert.addTextField { (alerTextField) in
            alerTextField.placeholder = "Create New Item"
            textFiel = alerTextField
        }
        
        let action = UIAlertAction(title: "Add Item", style: .default) { (action) in
            let text = textFiel.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            if text != "" {
                self.createItem(
                    title: text,
                    color: UIColor.randomFlat.hexValue(),
                    appSyncClient: self.appSyncClient!
                )
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .default) { (action) in
            //What Will Happen Once the User Click "Cancel" button on our UIAlert
        }
        
        alert.addAction(action)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }
}

//MARK: - Search Bar Method
extension TodoListViewController: UISearchBarDelegate {
    
    func withRequest(searchBar: UISearchBar) {
        searchItems(listID: List!.id!, text: searchBar.text!.lowercased(), appSyncClient: appSyncClient!)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        withRequest(searchBar: searchBar)
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text?.count == 0 {
            searchItems(listID: List!.id!, text: searchBar.text!, appSyncClient: appSyncClient!)
        }
        else {
            withRequest(searchBar: searchBar)
        }
    }
}

extension TodoListViewController {
    
    fileprivate func cleanCache(appSyncClient: AWSAppSyncClient) {
        do {
            try appSyncClient.clearCaches()
        } catch {
            print("Error Cleaning Cache: \(error)")
        }
    }
    
    fileprivate func getListItems(id: String, token: String) {
        
        SVProgressHUD.show()
        
        var cache = CachePolicy.returnCacheDataAndFetch
        var queryInput: ListListsItemsQuery?
        
        if token != "" && !refresing {
            queryInput = ListListsItemsQuery(list: id, limit: 10, nextToken: token)
        }
        else {
            queryInput = ListListsItemsQuery(list: id, limit: 20)
            self.List?.items = [Items]()
        }
        
        if refresing {
            cache = CachePolicy.fetchIgnoringCacheData
        }
        
        appSyncClient?.fetch(query: queryInput!, cachePolicy: cache) {(result, error) in
            
            if error != nil {
                print(error ?? "Error Getting Lists")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
            else {
                self.List?.items! = [Items]()
                result?.data?.listListsItems?.items!.forEach {
                    self.List?.items!.append(
                        Items(
                            id:           $0!.id,
                            title:        $0!.title,
                            search_title: $0!.searchTitle,
                            done:         $0!.done,
                            createdAt:    $0?.createdAt ?? "",
                            colorHex:     $0!.colorHex
                        )
                    )
                }
                
                if let nextToken = result?.data?.listListsItems?.nextToken {
                    self.nextItem = nextToken
                }
                else {
                    self.nextItem = ""
                }
                
                SVProgressHUD.dismiss()
                self.refresing = false
                self.tableView.refreshControl!.endRefreshing()
                self.tableView.reloadData()
            }
        }
    }
    
    fileprivate func createItem(title: String, color: String, appSyncClient: AWSAppSyncClient) {
        SVProgressHUD.show()
        let mutationInput = CreateItemInput(
            list:        self.List!.id!,
            title:       title,
            searchTitle: title.lowercased(),
            done:        false,
            colorHex:    color,
            listItemsId: self.List?.id)
        
        appSyncClient.perform(mutation: CreateItemMutation(input: mutationInput)) { (result, error) in
            
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
            else {
                print("ITEM SAVED")
                self.List?.items?.append(
                    Items(
                        id:           result?.data?.createItem?.id ?? "",
                        title:        result?.data?.createItem?.title ?? "",
                        search_title: result?.data?.createItem?.searchTitle ?? "",
                        done:         result?.data?.createItem?.done ?? false,
                        createdAt:    result?.data?.createItem?.createdAt ?? "",
                        colorHex:     result?.data?.createItem?.colorHex ?? ""
                    )
                )
                SVProgressHUD.showSuccess(withStatus: "Done")
                SVProgressHUD.dismiss(withDelay: 1)
                self.tableView.reloadData()
            }
        }
    }
    
    fileprivate func deleteItem(index: Int, appSyncClient: AWSAppSyncClient) {
        
        let item = List?.items![index]
        
        let mutationInput = DeleteItemInput(id: item!.id)
        appSyncClient.perform(mutation: DeleteItemMutation(input: mutationInput)) { (result, error) in
            
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
            else {
                print("ITEM DELETED")
                if self.List?.items?.count == 0 {
                    self.cleanCache(appSyncClient: appSyncClient)
                }
            }
        }
        self.List?.items?.remove(at: index)
    }
    
    fileprivate func updateItem(mutationInput: UpdateItemInput, appSyncClient: AWSAppSyncClient) {
        
        appSyncClient.perform(mutation: UpdateItemMutation(input: mutationInput)) { (result, error) in
            
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
                SVProgressHUD.dismiss()
            }
            if let resultError = result?.errors {
                print("Error Updating the item on server: \(resultError)")
                SVProgressHUD.dismiss()
                return
            }
            else {
                print("ITEM UPDATED")
                SVProgressHUD.dismiss()
                self.cleanCache(appSyncClient: appSyncClient)
            }
        }
    }
    
    fileprivate func SelectItem(index: Int, appSyncClient: AWSAppSyncClient) {
        
        let item = List?.items?[index]
        let mutationInput = UpdateItemInput(id: item!.id!, done: !item!.done!)
        updateItem(mutationInput: mutationInput, appSyncClient: appSyncClient)
        SVProgressHUD.dismiss()
        self.List?.items![index].done = !item!.done!
        self.tableView.reloadData()
    }
    
    fileprivate func updateItemTitle(index: Int, appSyncClient: AWSAppSyncClient) {
        
        let item     = self.List!.items![index]
        var textFiel = UITextField()
        let alert    = UIAlertController(title: "Update Item", message: "", preferredStyle: .alert)
        
        alert.addTextField { (alerTextField) in
            alerTextField.placeholder = "Update Item Title"
            alerTextField.text = item.title
            textFiel = alerTextField
        }
        
        let action = UIAlertAction(title: "Update", style: .default) { (action) in
            let text = textFiel.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            if text != "" {
                self.List!.items![index].title = text
                let mutationInput = UpdateItemInput(id: item.id!, title: text, searchTitle: textFiel.text!.lowercased())
//                SVProgressHUD.show()
                self.updateItem(mutationInput: mutationInput, appSyncClient: appSyncClient)
                self.tableView.reloadData()
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .default) { (action) in
            //What Will Happen Once the User Click "Cancel" button on our UIAlert
        }
        
        alert.addAction(action)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func searchItems(listID: String, text: String, appSyncClient: AWSAppSyncClient) {
        
        var search_items = [Items]()
        var queryInput: ListListsItemsQuery?
        let FilterInput = ModelItemFilterInput.init(searchTitle: ModelStringFilterInput(contains: text))
        
        if text != "" {
            queryInput = ListListsItemsQuery(list: listID, filter: FilterInput, limit: 20)
        }
        else {
             queryInput = ListListsItemsQuery(list: listID, limit: 20)
        }
        
        appSyncClient.fetch(query: queryInput!, cachePolicy: .returnCacheDataElseFetch) {(result, error) in
            
            if error != nil {
                print(error ?? "Error On Searsh")
            }
            if let resultError = result?.errors {
                print("Error searching items on server: \(resultError)")
                return
            }
            else {
                result?.data?.listListsItems?.items!.forEach {
                    search_items.append(
                        Items(
                            id:           $0!.id,
                            title:        $0!.title,
                            search_title: $0!.searchTitle,
                            done:         $0!.done,
                            createdAt:    $0?.createdAt ?? "",
                            colorHex:     $0!.colorHex
                        )
                    )
                }
                self.List!.items! = search_items
                self.tableView.reloadData()
            }
        }
        List!.items! = search_items
        tableView.reloadData()
    }
}


extension TodoListViewController: DeleteItemDelegate {
    func didDelete(index: Int) {
        deleteItem(index: index, appSyncClient: self.appSyncClient!)
    }
    
    func didUpdate(index: Int) {
        updateItemTitle(index: index, appSyncClient: self.appSyncClient!)
    }
}
