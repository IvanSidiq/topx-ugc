--[[
	# Homestore Template

	## Overview

	The UGC Homestore template aims to be a simple way for UGC creators to show  off and sell their items.

	Mannequins can be customized to show off bundles and accessories, which players can try on and purchase.
	The 2D shop UI automatically loads all of the place creator's UGC items and allows players to browse and purchase them.

	**Note**
	If the place is not published, default items published by Roblox are loaded.

	**Note**
	if you don't have any UGC items published, nothing will show up in the shop after publishing the template.
	This can be changed by setting `ReplicatedStorage.Settings.FETCH_CREATOR_NAME` to `false`.

	If you are a UGC creator, the following Mannequins and Shop sections will be of interest to you.
	The sections past that are technical and explain the project setup in more depth.

	## Mannequins

	Mannequins can be set up to display bundles and accessories.
	Players can inspect the mannequin to view and try on any items on it.

	Each mannequin has the 'Mannequin' tag applied for easy referencing by scripts.
	Items are set up using the `accessoryIds` and `bundleIds` attributes on each mannequin.
	Each attribute contains a comma-separated list of accessory or bundle IDs, respectively.

	**Note**
	Shoes include both a right and left shoe and so should be placed in the list of bundles.

	## Shop

	The 2D shop UI automatically fetches and populates with the place creator's UGC items.
	If the place has not been published, the fallback defined in `ReplicatedStorage.Settings.DEFAULT_CREATOR_NAME` is used instead.

	If you would like to always use the fallback, set `ReplicatedStorage.Settings.FETCH_CREATOR_NAME` to `false`.
	You can then adjust `DEFAULT_CREATOR_NAME` as you like to load a different creator's items.

	## Strict Mode

	Because we are working with a lot of data objects in this template, we opted to use strict mode for all code.
	This allows us to work with data more easily and make sure we're not running into various typing/naming issues.
	Since most of the APIs being used do not have built-in type information, we have defined types for most of
	the data objects in `ReplicatedStorage.Utility.Types`.

	## Restricted Items List

	The restricted items list is stored in `ReplicatedStorage.Libraries.RestrictedItems`.
	This can be used to define a list of items which are not purchasable using the included Purchase and BulkPurchase RemoteEvents.

	This is useful if you are implementing a UGC giveaway mechanic or something similar and don't want exploiters to be able to arbitrarily prompt and claim the item through the included RemoteEvents.

	## Project Structure

	Client scripts and objects are stored in ReplicatedStorage, the scripts have their
	RunContext set to Client so they do not need to be parented to PlayerScripts.

	Server scripts and objects are stored in ServerScriptService.

	### ReplicatedStorage.Client

	This folder holds the shop UI, try on, inspect, and audio scripts.

	### ReplicatedStorage.Libraries

	This folder contains the main client libraries, used to cache item details, handle the cart, etc.

	#### CameraOffset

	Used to apply an offset to the camera when the shop or inspect UI is open.

	#### Cart

	Handles the main cart functionality:

	- Storing items in the cart
	- Checkout logic
	- Removing items from the cart after purchasing

	#### ItemDetailsCache

	Implements caching for item details retrieved with `AvatarEditorService:GetItemDetails()`
	or `AvatarEditorService:SearchCatalog()`, this is used to avoid making constant http calls.

	#### ModalManager

	Handles layering of UI modals such as the shop and inspect UI.

	#### TryOn

	Handles the main try on functionality:

	- Storing which items are being tried on
	- Letting the server know when to update the character appearance

	### ReplicatedStorage.Remotes

	This folder contains the RemoteEvents.

	### ReplicatedStorage.UI

	This folder contains the UI objects and components.
	Components are implemented as single functions in ModuleScripts which instantiate the
	necessary instances as well as implement any necessary functionality.

	### ReplicatedStorage.Utility

	This folder contains various utility functions and classes used throughout the project.

	### ReplicatedStorage.Constants

	This module contains various constants used throughout the project.

	### ReplicatedStorage.Settings

	This module contains important settings, such as whether to automatically fetch the creator
	name and which name to use as a fallback.

	### ServerScriptService.Utility

	This folder contains utility functions used only on the server.
	In this case, this is just type validation functions used to validate RemoteEvent arguments.

	### ServerScriptService.Checkout

	This script handles individual and bulk purchasing functionality. The list of restricted items is checked
	here, allowing certain items to not be purchasable through the included Remotevents.

	### ServerScriptService.Mannequins

	This script sets up the mannequin visuals when the place starts up. Bundles and accessories
	are loaded from all the tagged mannequins and new mannequin models are created using
	`Players:CreateHumanoidModelFromDescription`.

	### ServerScriptService.TryOn

	This script handles the try on functionality, reloading player appearances with the selected
	items they are trying on. When applying the new description with `Humanoid:ApplyDescription`,
	`Enum.AssetTypeVerification.Always` is used to ensure players are not able to load non-accessory assets.
]]
