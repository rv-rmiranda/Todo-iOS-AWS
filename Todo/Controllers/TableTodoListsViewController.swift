import UIKit
import SwipeCellKit
import SVProgressHUD
import ChameleonFramework

/* AWS */
import AWSAppSync
import AWSMobileClient

class TableTodoListsViewController: SwipeTableViewController {
    
    fileprivate var categories = [Todo]()
    fileprivate var userName: String?
    
    //MARK: - AWS AppSync Variables:
    fileprivate weak var appSyncClient: AWSAppSyncClient?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let appDelegate  = UIApplication.shared.delegate as! AppDelegate
        appSyncClient    = appDelegate.appSyncClient
        tableView.tag    = 0
        CategoryDelegate = self
        setAuth()
    }
    
    // MARK: - TableView Datasource Methods
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! SwipeTableViewCell
        cell.delegate = self
        cell.textLabel?.text = categories[indexPath.row].title ?? "Add new categories!"
        
        if let colorHex = UIColor(hexString: (categories[indexPath.row].colorHex)!) {
            cell.backgroundColor      = colorHex
            cell.textLabel?.textColor = ContrastColorOf(colorHex, returnFlat: true)
        }
        return cell
    }
    
    
    // MARK: - TableView Delegate Methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "goToItems", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let destinationVC = segue.destination as! TodoItemsViewController
        if let indexPath  = tableView.indexPathForSelectedRow {
            destinationVC.List = categories[indexPath.row]
        }
    }
    
    @IBAction func signOut(_ sender: Any) {
        AWSMobileClient.sharedInstance().signOut()
        setAuth()
        categories = [Todo]()
    }
    
    //MARK: - Data Manipulation Methods
    @IBAction func addButtonPressed(_ sender: UIBarButtonItem) {
        
        var textFiel = UITextField()
        
        let alert = UIAlertController(title: "Add New Category", message: "", preferredStyle: .alert)
        alert.addTextField { (alertTextFiel) in
            alertTextFiel.placeholder = "Create New Category"
            textFiel = alertTextFiel
        }
        
        let action = UIAlertAction(title: "Add", style: .default) { (action) in
            let text = textFiel.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            if text != "" {
                self.newTodo(user: self.userName!, name: text, color: UIColor.randomFlat.hexValue(), appSyncClient: self.appSyncClient!)
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .default) { (cancel) in
            
        }
        alert.addAction(action)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }
}

extension TableTodoListsViewController: SwipeCategoryDelegate {
    
    func didDelete(index: Int) {
        deleteTodo(index: index, appSyncClient: self.appSyncClient!)
    }
    
    func didUpdate(index: Int) {
        updateTodoTitle(index: index, appSyncClient: self.appSyncClient!)
    }
}

//MARK: - AppSync Integration with API.swift
extension TableTodoListsViewController {
    
    fileprivate func setUserName() {
        if let username = AWSMobileClient.sharedInstance().username {
            userName = username
        }
    }
    
    fileprivate func setAuth() {
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            if let userState = userState {
                switch(userState){
                case .signedIn:
                    DispatchQueue.main.async {
                        print("UserState: \(userState.rawValue)")
                        if self.appSyncClient != nil {
                            self.setUserName()
                            self.getList(user: self.userName!, appSyncClient: self.appSyncClient!)
                        }
                    }
                case .signedOut:
                    AWSMobileClient.sharedInstance().showSignIn(navigationController: self.navigationController!, signInUIOptions: SignInUIOptions(
                        canCancel: false,
                        logoImage: UIImage(named: "fwd787"),
                        backgroundColor: UIColor.lightGray), { (userState, error) in
                        if(error == nil){       // Successful signin
                            DispatchQueue.main.async {
                                if self.appSyncClient != nil {
                                    self.cleanCache(appSyncClient: self.appSyncClient!)
                                    self.setUserName()
                                    self.getList(user: self.userName!, appSyncClient: self.appSyncClient!)
                                }
                            }
                        } else {
                            print(userState!)
                        }
                    })
                default:
                    AWSMobileClient.sharedInstance().signOut()
                }
                
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    fileprivate func cleanCache(appSyncClient: AWSAppSyncClient) {
        do {
            try appSyncClient.clearCaches()
        } catch {
            print("Error Cleaning Cache: \(error)")
        }
    }
    
    fileprivate func getList(user: String, appSyncClient: AWSAppSyncClient) {
        
        SVProgressHUD.show()
        var todo = [Todo]()
        
        appSyncClient.fetch(query: ListUserListsQuery(owner: user), cachePolicy: .returnCacheDataAndFetch) {(result, error) in
            
            if error != nil {
                print(error ?? "Error Getting Lists")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
            else {
                todo = []
                result?.data?.listUserLists?.items!.forEach {
                    todo.append(
                        Todo(
                            id:        $0!.id,
                            title:     $0!.title,
                            colorHex:  $0!.colorHex,
                            createdAt: $0?.createdAt ?? "",
                            items:     [Items]()
                        )
                    )
                }
                self.categories = todo
                SVProgressHUD.dismiss()
                self.tableView.reloadData()
            }
        }
    }
    
    fileprivate func newTodo(user: String, name: String, color: String, appSyncClient: AWSAppSyncClient) {
        SVProgressHUD.show()
        let mutationInput = CreateListInput(owner: user, title: name, colorHex: color)
        appSyncClient.perform(mutation: CreateListMutation(input: mutationInput)) { (result, error) in
            
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
            else {
                print("TODO SAVED")
                    self.categories.append(
                        Todo(
                            id:        result?.data?.createList?.id ?? "",
                            title:     result?.data?.createList?.title ?? "",
                            colorHex:  result?.data?.createList?.colorHex ?? "",
                            createdAt: result?.data?.createList?.createdAt ?? "",
                            items:     [Items]()
                    ))
                SVProgressHUD.showSuccess(withStatus: "Done")
                SVProgressHUD.dismiss(withDelay: 1)
                self.tableView.reloadData()
            }
        }
    }
    
    fileprivate func updateItem(mutationInput: UpdateListInput, appSyncClient: AWSAppSyncClient) {
        
        SVProgressHUD.show()
        appSyncClient.perform(mutation: UpdateListMutation(input: mutationInput)) { (result, error) in
            
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription)")
                SVProgressHUD.showError(withStatus: error.localizedDescription)
                SVProgressHUD.dismiss(withDelay: 3)
            }
            if let resultError = result?.errors {
                print("Error Updating the List on server: \(resultError)")
                SVProgressHUD.showError(withStatus: "\(resultError)")
                SVProgressHUD.dismiss(withDelay: 3)
                return
            }
            else {
                print("LIST UPDATED")
                SVProgressHUD.dismiss()
                self.cleanCache(appSyncClient: appSyncClient)
                self.tableView.reloadData()
            }
        }
    }
    
    fileprivate func updateTodoTitle(index: Int, appSyncClient: AWSAppSyncClient) {
        
        var textFiel = UITextField()
        let item     =  self.categories[index]
        
        let alert = UIAlertController(title: "Update Item", message: "", preferredStyle: .alert)
        alert.addTextField { (alerTextField) in
            alerTextField.placeholder = "Update Item Title"
            alerTextField.text = item.title
            textFiel = alerTextField
        }
        
        let action = UIAlertAction(title: "Update", style: .default) { (action) in
            let text = textFiel.text!.trimmingCharacters(in: .whitespacesAndNewlines)
            if text != "" {
                item.title = text
                let mutationInput = UpdateListInput(id: item.id!, title: text)
                self.updateItem(mutationInput: mutationInput, appSyncClient: appSyncClient)
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .default) { (action) in
            //What Will Happen Once the User Click "Cancel" button on our UIAlert
        }
        alert.addAction(action)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func deleteTodo(index: Int, appSyncClient: AWSAppSyncClient) {
        
        let item = categories[index]
        
        let mutationInput = DeleteListInput(id: item.id)
        appSyncClient.perform(mutation: DeleteListMutation(input: mutationInput)) { (result, error) in
            
            if let error = error as? AWSAppSyncClientError {
                print("Error occurred: \(error.localizedDescription )")
            }
            if let resultError = result?.errors {
                print("Error saving the item on server: \(resultError)")
                return
            }
            else {
                print("TODO LIST DELETED")
                if self.categories.count == 0 {
                    self.cleanCache(appSyncClient: appSyncClient)
                }
            }
        }
        categories.remove(at: index)
    }
}
