import Cocoa
import MartaApi
import SwiftyJSON

public class NetExistentialtypeOpenerPlugin : NSObject, Plugin, ActionProvider {
  public let name = "opener"
  public let author = "Geoffrey Washburn"
  public let email = "washburn@acm.org"
  
  public var actions: [Action] {
    return [ NetExistentialtypeOpenerAction() ]
  }
}

/** Helper to collect up the Actions Opener may use. */
struct OpenerActions {
  
  let directoryAction: Action
  let defaultAction: Action
  let extMap: [String : Action]
  
  init(context: GlobalContext) {
    typealias Config = NetExistentialtypeOpenerConfiguration
    
    let actRepo = context.actionRepository
    
    let dirActKey = Config.directoryActionName
    let defActKey = Config.defaultActionName
    
    /* Look up the names of the actions to use. */
    
    let dirActName = context.get(dirActKey)
    let defActName = context.get(defActKey)
    let extMapNames = context.get(Config.extensionActionMap)
    
    /* Fetch the actions we'll be using. */
    
    /* The default fallbacks should always exist unless Marta itself changes,
     * so forcing the unwrapping should be safe.
     *
     * Ideally we would cache these lookups somehow?
     */

    directoryAction =
      (actRepo[dirActName] ?? actRepo[dirActKey.defaultValue!])!
    defaultAction =
      (actRepo[defActName] ?? actRepo[defActKey.defaultValue!])!
    
    var tmpExtMap: [String : Action] = [String : Action]()
    extMapNames.forEach { (ext, actName) in
      if let act = actRepo[actName] {
        tmpExtMap[ext]=act
      }
    }
    extMap = tmpExtMap

  }
}

class NetExistentialtypeOpenerAction : Action {
  let id = "net.existentialtype.opener"
  let name = "Opener"
  let shortName = "Opener"
  /* Should find a better choice, but HIG does say 
   * 'Opens or represents a folder.'
   */ 
  let touchBarIcon = NSImage(named: NSImageNameTouchBarFolderTemplate)
  
  func isApplicable(context: ActionContext) -> Bool {
    return true
  }
  
  func apply(context: ActionContext) {
    let actions = OpenerActions(context: context.globalContext)
    
    let model = context.activePane.mutableModel
    let activeItems = model.activeItems
    
    /* In order to better match the default behavior of "core.open" on 
     * directories, we first only look at the currentItem and act on it
     * if it is a directory.
     */
    if let item = model.currentItem {
      /* First check to see if we are trying to open a directory. */
      if (item.isDirectory || item is GoUpVirtualFile) {
        actions.directoryAction.apply(context: context)
        return
      }
    }
    
    var allItems: [VirtualFile] = []
    allItems += activeItems
    /* Seems like there should be a cleaner way to do this. */
    if let item = model.currentItem {
      /* Only add the current item if isn't already an activeItem.
       * Is really comparing by hashValue the best I can do here?
       */
      if (!allItems.contains(where: {$0.hashValue == item.hashValue})) {
        allItems.append(item)
      }
    }
    
    /* Currently, can only handle one item for special casing, as
     * there does not seem to be a good way to rewrite the context
     * before delegating to another action.
     */
    if (allItems.count == 1) {
      let item = allItems.first!
      if let act = actions.extMap[item.fileExtension] {
        /* Check if there is a specified action for this file extension */
        act.apply(context: context)
      } else {
        /* Otherwise, use the default action. */
        actions.defaultAction.apply(context: context)
      }
    } else {
      actions.defaultAction.apply(context: context)
    }
  }
}

/** Specialization of ConfigurationKey for JSON key-value maps. */
class MapConfigurationKey : ConfigurationKey<[(String, String)]> {
  
  public override func map(_ json: Json) -> [(String, String)]? {
    var map: [(String, String)] = []
    for (key,subJson):(String, JSON) in json as! JSON {
      map.append(key, subJson.stringValue)
    }
    return map
  }
  
  public override func map(_ value: [(String, String)]) -> Json {
    return JSON(dictionaryLiteral: value.map {($0, $1 as Any)})
  }
}

extension ConfigurationSlice {
  static func mapKey(_ path: String,
                     _ defaultValue: [(String, String)] = []) -> ConfigurationKey<[(String, String)]> {
    return MapConfigurationKey(fullPath(path), defaultValue)
  }
}

/** Static configuration slice. */
class NetExistentialtypeOpenerConfiguration : ConfigurationSlice {
  private init() {}
  
  static let basePath = "behavior|actions|net.existentialtype.opener"
  
  /** The action to use for directories. */
  static let directoryActionName = stringKey("directoryAction", "core.open")
  /** The action to use for everything else. */
  static let defaultActionName = stringKey("defaultAction", "core.open.with")
  
  /* Mapping from extensions to chosen actions. */
  static let extensionActionMap = mapKey("extensionActions", [])
}
