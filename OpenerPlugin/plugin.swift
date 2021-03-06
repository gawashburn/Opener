import Cocoa
import MartaApi
import SwiftyJSON

public class NetExistentialtypeOpenerPlugin : NSObject, Plugin, ActionProvider {
  public let name = "opener"
  public let author = "Geoffrey Washburn"
  public let email = "washburn@acm.org"

  public let requiredApiVersion = ApiVersion(major: 4, minor: 5)
  
  public var actions: [Action] {
    return [ NetExistentialtypeOpenerAction() ]
  }
}

class NetExistentialtypeOpenerAction : Action {
  // Define the id statically so that inner static methods can
  // refer to it without an instance
  private static let commonId = "net.existentialtype.opener"
  let id = commonId

  let name = "Opener"
  let shortName = "Opener"

  // We determine the Touch Bar icon in init.
  var touchBarIcon: NSImage?

  typealias Config = NetExistentialtypeOpenerConfiguration

  // Structure to hold all the Actions Opener may use.
  private struct ActionCache {

    let specialActions: [String: Action]
    let extMap: [String : Action]

    func extAction(ext: String) -> Action {
      // Check if there is a specified action for this file extension.
      // Otherwise, use the default action.
      return extMap[ext] ?? specialActions[Config.defaultActionName]!
    }

    // Helper to pop up an alert
    private static func errAlert(msg: String, show: Bool) {
      if (show) {
        let a = NSAlert()
        a.messageText = msg
        a.alertStyle = .informational
        a.addButton(withTitle: "Close")
        a.runModal()
      }
    }

    // Helper to look up actions possibly reporting an error
    private static func lookup(actions: ActionRepository,
                               name: String,
                               defName: String,
                               def: String,
                               errAlert: Bool) -> Action  {
      // Seems like there must be a nicer pattern here?
      if let act = actions[name] {
        // Check that the action isn't Opener itself
        if (act.id != NetExistentialtypeOpenerAction.commonId) {
          return act
        }
        ActionCache.errAlert(msg:
          "Opener Plugin: Cannot proxy through itself, using the " + defName +
              " action of '" + def + "'.", show: errAlert)
      } else {
        // Marta doesn't load the plugin if I use string interpolation instead
        // of +? What is going on?
        ActionCache.errAlert(msg:
          "Opener Plugin: There is no action named '" + name + "', using the " +
              defName + " action of '" + def + "'.", show: errAlert)
      }
      // The default fallbacks should always exist unless Marta itself changes,
      // so forcing the unwrapping should be safe.
      return actions[def]!
    }

    init(context: GlobalContext) {
      let errAlerts = context.get(Config.errorAlerts)

      let actRepo = context.actionRepository

      // Specialized actions
      let keys: [(String, ConfigurationKey<String>, String)] = [
        // FIX?? Seems like there should be a way to go from the key to its
        // name? Or get they key from its name?
        (Config.directoryActionName, Config.directoryAction, "default directory"),
        (Config.applicationActionName, Config.applicationAction, "default application"),
        (Config.packageActionName, Config.packageAction, "default package"),
        (Config.defaultActionName, Config.defaultAction, "default")
      ]

      // Fetch the specialized actions we'll be using.
      var tmpSpecialActions: [String: Action] = [:]
      for (name, key, defName) in keys {
        // Look up the name of the action to use for the given key
        let actName = context.get(key)

        tmpSpecialActions[name] = ActionCache.lookup(
            actions: actRepo,
            name: actName,
            defName: defName,
            def: key.defaultValue!,
            errAlert: errAlerts)
      }
      specialActions = tmpSpecialActions

      // Look up all the other actions specified by extension

      let extMapNames = context.get(Config.extensionActionMap)

      // Need to use temporary as we can't assign directly to extMap?
      var tmpExtMap: [String : Action] = [String : Action]()
      extMapNames.forEach { (ext, actName) in
        if let act = actRepo[actName] {
          // Check that the action isn't Opener itself
          if (act.id != NetExistentialtypeOpenerAction.commonId) {
            tmpExtMap[ext]=act
          } else {
            ActionCache.errAlert(msg:
              "Opener Plugin: Cannot proxy through itself, ignoring the definition for '" +
                  ext + "'.", show: errAlerts)
          }
        } else {
          // Marta doesn't load the plugin if I use string interpolation instead
          // of +? What is going on?
          ActionCache.errAlert(msg:
            "Opener Plugin: There is no action named '" + actName +
                "', ignoring the definition for '" + ext + "'.", show: errAlerts)
        }
      }
      extMap = tmpExtMap
    }
  }

  // Create a specialized MutableListModel to use when dispatching actions
  private class OpenerModel : DelegateMutableListModel {
    private var itemIndex: Int
    private var itemIndicies: Set<Int>

    init(itemIndicies: Set<Int>, delegate: MutableListModel) {
      // Needs improvement here.  The goal of using -1 is to make
      // sure the action focuses only on the selected set of items.
      // However, it seems like some actions like "core.open.with"
      // only use the currentItemIndex?
      self.itemIndex = -1
      self.itemIndicies = itemIndicies
      super.init(delegate: delegate)
    }

    // Need to override because just modifying the fields would mutate the original model delegate instead.
    override var currentItemIndex: Int { get { return itemIndex } set { itemIndex = newValue } }
    override var selectedItemIndices: Set<Int> { get { return itemIndicies } set { itemIndicies = newValue } }
  }

  // Assuming it is safe to expect that if Marta were to reload
  // its configuration, it would create a fresh instance of
  // this Action so that a stale cache cannot be used.
  private var actionsCache: ActionCache? = nil

  init() {
    // If using a new enough macOS, use the HIG TouchBar Share icon.
    if #available(macOS 10.12.2, *) {
      // Should find a better choice, but HIG does say
      // 'Opens or represents a folder.'
      touchBarIcon = NSImage(named: NSImage.Name.touchBarFolderTemplate)
      // Otherwise, use protocol default.
    } else {
      touchBarIcon = (self as Action).touchBarIcon
    }
  }

  func isApplicable(context: ActionContext) -> Bool {
    return true
  }
  
  func apply(context: ActionContext) {
    // Check if the cache hasn't yet been initialized.
    if (actionsCache == nil) {
      actionsCache = ActionCache(context: context.globalContext)
    }
    let actions = actionsCache!

    let model = context.activePane.mutableModel

    // In order to better match the default behavior of "core.open" on
    // directories, we first only look at the currentItem and act on it
    // if it is a directory, ignoring the selection
    if let item = model.currentItem {
      // First check to see if we are trying to open a directory.
      if (item.isDirectory || item is GoUpVirtualFile) {
        // Next check that this directory isn't also an Application or Package
        if let localFile = item as? LocalFile {
          if (localFile.isApplication) {
            actions.specialActions[Config.applicationActionName]!.apply(context: context)
            return
          } else if (localFile.isPackage) {
            actions.specialActions[Config.packageActionName]!.apply(context: context)
            return
          }
        }
        actions.specialActions[Config.directoryActionName]!.apply(context: context)
        return
      }
    }

    // Next check to see if there are selected items.  "core.open" seems
    // to ignore currentItem (if it isn't a directory) when there are
    // selected items.  So we'll dispatch on them.
    if (!model.selectedItems.isEmpty) {
      let extMap = actions.extMap

      // Per extension buckets
      var extIndicies: [String : Set<Int>] = [:]
      // Default bucket
      var defaultIndicies = Set<Int>()

      // Classify selected items into buckets
      model.selectedItemIndices.forEach { (itemIndex) in
        let ext = model.items[itemIndex].fileExtension
        if extMap.index(forKey: ext) != nil {
          if var indicies = extIndicies[ext] {
            indicies.insert(itemIndex)
          } else {
            // Why doesn't Set<Int>([itemIndex]) work?
            var tmpSet = Set<Int>()
            tmpSet.insert(itemIndex)
            extIndicies[ext] = tmpSet
          }
        } else {
          defaultIndicies.insert(itemIndex)
        }
      }

      // Use the defined action for each bucket
      extIndicies.forEach{ (ext, indicies) in
        let newModel = OpenerModel(itemIndicies: indicies, delegate: model)
        let newContext = context.clone(newModelForActiveTab: newModel)
        extMap[ext]!.apply(context: newContext)
      }

      // Apply the default action on whatever is left.
      if (!defaultIndicies.isEmpty) {
        let newModel = OpenerModel(itemIndicies: defaultIndicies, delegate: model)
        let newContext = context.clone(newModelForActiveTab: newModel)

        actions.specialActions[Config.defaultActionName]!.apply(context: newContext)
      }

    // Otherwise, just act on the current item, which does not require
    // rewriting the model
    } else if let item = model.currentItem {
      actions.extAction(ext: item.fileExtension).apply(context: context)
    }
  }
}

/** Specialization of ConfigurationKey for JSON key-value maps. */
class MapConfigurationKey : ConfigurationKey<[(String, String)]> {
  
  public override func map(_ json: Json) -> [(String, String)]? {
    var map: [(String, String)] = []
    for (key,subJson):(String, JSON) in json as! JSON {
      map.append((key, subJson.stringValue))
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

  /** The action to use for applications. */
  static let applicationActionName = "applicationAction"
  static let applicationAction = stringKey(applicationActionName, "core.open")

  /** The action to use for packages. */
  static let packageActionName = "packageAction"
  static let packageAction = stringKey(packageActionName, "core.open.with")

  /** The action to use for directories. */
  static let directoryActionName = "directoryAction"
  static let directoryAction = stringKey(directoryActionName, "core.open")

  /** The action to use for everything else. */
  static let defaultActionName = "defaultAction"
  static let defaultAction = stringKey(defaultActionName, "core.open.with")
  
  /** Mapping from extensions to chosen actions. */
  static let extensionActionMap = mapKey("extensionActions", [])

  /** Should the plugin open alerts to report errors. */
  static let errorAlerts = boolKey("errorAlerts", true)
}
