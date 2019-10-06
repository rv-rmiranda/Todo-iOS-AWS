import UIKit
import SwipeCellKit
import ChameleonFramework

protocol SwipeCategoryDelegate {
    func didDelete(index: Int)
    func didUpdate(index: Int)
}

protocol DeleteItemDelegate {
    func didDelete(index: Int)
    func didUpdate(index: Int)
}

var CategoryDelegate: SwipeCategoryDelegate?
var ItemDelegate: DeleteItemDelegate?

class SwipeTableViewController: UITableViewController, SwipeTableViewCellDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorStyle = .none
        tableView.rowHeight      = 80.0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! SwipeTableViewCell
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> [SwipeAction]? {
        
        var detectedAction: SwipeAction
        if orientation == .left {
            detectedAction = SwipeAction(style: .default , title: "Edit") { action, indexPath in
                switch tableView.tag {
                case 0:
                    CategoryDelegate?.didUpdate(index: indexPath.row)
                case 1:
                    ItemDelegate?.didUpdate(index: indexPath.row)
                default:
                    print("Add Analytics")
                }
            }
            
            // customize the action appearance
            detectedAction.image = UIImage(named: "more")
            detectedAction.backgroundColor = .clear
            
        } else {
            detectedAction = SwipeAction(style: .default, title: "Delete") { action, indexPath in
                switch tableView.tag {
                case 0:
                    CategoryDelegate?.didDelete(index: indexPath.row)
                case 1:
                    ItemDelegate?.didDelete(index: indexPath.row)
                default:
                    print("Add Analytics")
                }
            }
            
            // customize the action appearance
            detectedAction.image = UIImage(named: "delete")
            detectedAction.backgroundColor = .clear
        }
        
        return [detectedAction]
    }
    
    func tableView(_ tableView: UITableView, editActionsOptionsForRowAt indexPath: IndexPath, for orientation: SwipeActionsOrientation) -> SwipeOptions {
        var options = SwipeOptions()
        if orientation == .right {
            options.expansionStyle  = .destructive
            options.transitionStyle = .border
            options.backgroundColor = .red
        } else {
            options.expansionStyle  = .selection
            options.transitionStyle = .drag
            options.backgroundColor = .flatBlue
        }
        return options
    }
}
