class_name ItemData

enum ItemType {
	GOLD,
	LARGE_HEALTH_POTION,
	SMALL_HEALTH_POTION,
	KEY
}

class ItemDescription:
	var name: String
	var description: String

	func _init(name: String, description: String):
		self.name = name
		self.description = description

static var item_descriptions: Dictionary[ItemType, ItemDescription] = {
	ItemType.GOLD: ItemDescription.new("Gold", "A piece of gold"),
	ItemType.LARGE_HEALTH_POTION: ItemDescription.new("Large health potion", "A large health potion"),
	ItemType.SMALL_HEALTH_POTION: ItemDescription.new("Small health potion", "A small health potion"),
	ItemType.KEY: ItemDescription.new("Key", "A door key"),
}
