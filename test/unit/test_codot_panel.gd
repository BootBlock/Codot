## Unit tests for Codot Panel prompt management
extends GutTest

const CodotPanelScript := preload("res://addons/codot/codot_panel.gd")

var panel: Control


func before_each() -> void:
	# Create panel instance from scene
	var panel_scene := load("res://addons/codot/codot_panel.tscn")
	panel = panel_scene.instantiate()
	add_child_autofree(panel)
	await wait_frames(2)


func after_each() -> void:
	panel = null


#region Prompt Creation Tests

func test_create_prompt_returns_valid_id() -> void:
	var prompt_id: String = panel.create_prompt("Test Title", "Test content")
	
	assert_ne(prompt_id, "", "Should return a non-empty ID")
	assert_eq(prompt_id.length(), 12, "ID should be 12 characters")


func test_create_prompt_with_empty_title_uses_default() -> void:
	var prompt_id: String = panel.create_prompt("", "Content")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.title, "Untitled Prompt", "Empty title should use default")


func test_create_prompt_adds_to_active_list() -> void:
	var before_count: int = panel.get_active_prompts().size()
	panel.create_prompt("Test", "Content")
	var after_count: int = panel.get_active_prompts().size()
	
	assert_eq(after_count, before_count + 1, "Should add one prompt")


func test_create_prompt_sets_created_at() -> void:
	var prompt_id: String = panel.create_prompt("Test", "Content")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_true(prompt.has("created_at"), "Should have created_at field")
	assert_ne(prompt.created_at, "", "created_at should not be empty")

#endregion


#region Prompt Retrieval Tests

func test_get_prompt_returns_correct_data() -> void:
	var prompt_id: String = panel.create_prompt("My Title", "My Content")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.id, prompt_id, "ID should match")
	assert_eq(prompt.title, "My Title", "Title should match")
	assert_eq(prompt.content, "My Content", "Content should match")
	assert_eq(prompt.archived, false, "Should not be archived")


func test_get_prompt_with_invalid_id_returns_empty() -> void:
	var prompt: Dictionary = panel.get_prompt("nonexistent_id")
	
	assert_true(prompt.is_empty(), "Should return empty dict for invalid ID")


func test_get_active_prompts_excludes_archived() -> void:
	var id1: String = panel.create_prompt("Active", "Content")
	var id2: String = panel.create_prompt("To Archive", "Content")
	panel._archive_prompt(id2)
	
	var active: Array = panel.get_active_prompts()
	var ids: Array[String] = []
	for p in active:
		ids.append(p.id)
	
	assert_true(ids.has(id1), "Should include active prompt")
	assert_false(ids.has(id2), "Should exclude archived prompt")


func test_get_archived_prompts_only_includes_archived() -> void:
	var id1: String = panel.create_prompt("Active", "Content")
	var id2: String = panel.create_prompt("Archived", "Content")
	panel._archive_prompt(id2)
	
	var archived: Array = panel.get_archived_prompts()
	var ids: Array[String] = []
	for p in archived:
		ids.append(p.id)
	
	assert_false(ids.has(id1), "Should exclude active prompt")
	assert_true(ids.has(id2), "Should include archived prompt")

#endregion


#region Prompt Update Tests

func test_update_prompt_changes_title() -> void:
	var prompt_id: String = panel.create_prompt("Old Title", "Content")
	var result: bool = panel.update_prompt(prompt_id, "New Title", "Content")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_true(result, "Update should succeed")
	assert_eq(prompt.title, "New Title", "Title should be updated")


func test_update_prompt_changes_content() -> void:
	var prompt_id: String = panel.create_prompt("Title", "Old Content")
	panel.update_prompt(prompt_id, "Title", "New Content")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.content, "New Content", "Content should be updated")


func test_update_prompt_with_invalid_id_returns_false() -> void:
	var result: bool = panel.update_prompt("nonexistent", "Title", "Content")
	
	assert_false(result, "Update should fail for invalid ID")

#endregion


#region Prompt Deletion Tests

func test_delete_prompt_removes_from_list() -> void:
	var prompt_id: String = panel.create_prompt("Test", "Content")
	var before_count: int = panel.get_active_prompts().size()
	
	var result: bool = panel.delete_prompt(prompt_id)
	var after_count: int = panel.get_active_prompts().size()
	
	assert_true(result, "Delete should succeed")
	assert_eq(after_count, before_count - 1, "Should remove one prompt")


func test_delete_prompt_with_invalid_id_returns_false() -> void:
	var result: bool = panel.delete_prompt("nonexistent")
	
	assert_false(result, "Delete should fail for invalid ID")


func test_delete_prompt_makes_get_return_empty() -> void:
	var prompt_id: String = panel.create_prompt("Test", "Content")
	panel.delete_prompt(prompt_id)
	
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	assert_true(prompt.is_empty(), "Deleted prompt should not be retrievable")

#endregion


#region Archive Tests

func test_archive_prompt_sets_archived_flag() -> void:
	var prompt_id: String = panel.create_prompt("Test", "Content")
	panel._archive_prompt(prompt_id)
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_true(prompt.archived, "Should be archived")


func test_archive_prompt_sets_archived_at_timestamp() -> void:
	var prompt_id: String = panel.create_prompt("Test", "Content")
	panel._archive_prompt(prompt_id)
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_true(prompt.has("archived_at"), "Should have archived_at")
	assert_ne(prompt.archived_at, "", "archived_at should not be empty")


func test_restore_prompt_clears_archived_flag() -> void:
	var prompt_id: String = panel.create_prompt("Test", "Content")
	panel._archive_prompt(prompt_id)
	panel.restore_prompt(prompt_id)
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_false(prompt.archived, "Should not be archived after restore")
	assert_false(prompt.has("archived_at"), "Should not have archived_at after restore")


func test_archive_with_invalid_id_returns_false() -> void:
	var result: bool = panel._archive_prompt("nonexistent")
	assert_false(result, "Archive should fail for invalid ID")


func test_restore_with_invalid_id_returns_false() -> void:
	var result: bool = panel.restore_prompt("nonexistent")
	assert_false(result, "Restore should fail for invalid ID")

#endregion


#region Edge Case Tests

func test_create_multiple_prompts() -> void:
	var id1: String = panel.create_prompt("First", "Content 1")
	var id2: String = panel.create_prompt("Second", "Content 2")
	var id3: String = panel.create_prompt("Third", "Content 3")
	
	assert_ne(id1, id2, "IDs should be unique")
	assert_ne(id2, id3, "IDs should be unique")
	assert_ne(id1, id3, "IDs should be unique")
	
	var active: Array = panel.get_active_prompts()
	assert_eq(active.size(), 3, "Should have 3 active prompts")


func test_empty_content_allowed() -> void:
	var prompt_id: String = panel.create_prompt("Empty Content", "")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.content, "", "Empty content should be allowed")


func test_special_characters_in_title() -> void:
	var special_title := "Test <>&\"'`~!@#$%^*()[]{}|\\:;,./?"
	var prompt_id: String = panel.create_prompt(special_title, "Content")
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.title, special_title, "Special chars should be preserved")


func test_multiline_content() -> void:
	var multiline := "Line 1\nLine 2\nLine 3\n\n\tIndented"
	var prompt_id: String = panel.create_prompt("Multiline", multiline)
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.content, multiline, "Multiline content should be preserved")


func test_unicode_in_prompt() -> void:
	var unicode_content := "日本語テスト 🎮 Ñoño émoji 中文"
	var prompt_id: String = panel.create_prompt("Unicode Test", unicode_content)
	var prompt: Dictionary = panel.get_prompt(prompt_id)
	
	assert_eq(prompt.content, unicode_content, "Unicode should be preserved")

#endregion
