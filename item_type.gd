class_name ItemData

enum ItemType {
	GOLD,
	LARGE_HEALTH_POTION,
	SMALL_HEALTH_POTION,
	KEY,
	WOODEN_SHIELD,
	DAGGER,
	TORCH,
}

class ItemDescription:
	var name: String
	var description: String

	func _init(name: String, description: String):
		self.name = name
		self.description = description

static var item_descriptions: Dictionary[ItemType, ItemDescription] = {
	ItemType.GOLD: ItemDescription.new("Strange treasure", "A bizarre artefact"),
	ItemType.LARGE_HEALTH_POTION: ItemDescription.new("Large health potion", "A large health potion"),
	ItemType.SMALL_HEALTH_POTION: ItemDescription.new("Small health potion", "A small health potion"),
	ItemType.KEY: ItemDescription.new("Key", "A door key"),
	ItemType.WOODEN_SHIELD: ItemDescription.new("Wooden shield", "A simple wooden shield"),
	ItemType.DAGGER: ItemDescription.new("Dagger", "A small dagger"),
	ItemType.TORCH: ItemDescription.new("Torch", "A small torch"),
}
