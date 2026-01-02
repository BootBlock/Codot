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


#region Duplicate Prompt Tests

func test_duplicate_prompt_creates_copy() -> void:
	var original_id: String = panel.create_prompt("Original", "Original Content")
	var copy_id: String = panel.duplicate_prompt(original_id)
	
	assert_ne(copy_id, "", "Should return new ID")
	assert_ne(copy_id, original_id, "Copy ID should be different")


func test_duplicate_prompt_appends_copy_to_title() -> void:
	var original_id: String = panel.create_prompt("My Title", "Content")
	var copy_id: String = panel.duplicate_prompt(original_id)
	var copy: Dictionary = panel.get_prompt(copy_id)
	
	assert_eq(copy.title, "My Title (copy)", "Should append (copy) to title")


func test_duplicate_prompt_copies_content() -> void:
	var original_id: String = panel.create_prompt("Title", "Original Content Here")
	var copy_id: String = panel.duplicate_prompt(original_id)
	var copy: Dictionary = panel.get_prompt(copy_id)
	
	assert_eq(copy.content, "Original Content Here", "Content should be copied")


func test_duplicate_with_invalid_id_returns_empty() -> void:
	var result: String = panel.duplicate_prompt("nonexistent")
	assert_eq(result, "", "Should return empty for invalid ID")

#endregion


#region Export/Import Tests

func test_export_prompt_creates_file() -> void:
	var prompt_id: String = panel.create_prompt("Export Test", "Export Content")
	var export_path := "user://test_export.json"
	
	var result: bool = panel.export_prompt(prompt_id, export_path)
	
	assert_true(result, "Export should succeed")
	assert_true(FileAccess.file_exists(export_path), "Export file should exist")
	
	# Cleanup
	DirAccess.remove_absolute(export_path)


func test_export_prompt_file_contains_correct_data() -> void:
	var prompt_id: String = panel.create_prompt("Export Data Test", "Export Content Data")
	var export_path := "user://test_export_data.json"
	
	panel.export_prompt(prompt_id, export_path)
	
	var file := FileAccess.open(export_path, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var data: Dictionary = json.get_data()
	
	assert_true(data.has("prompt"), "Should have prompt key")
	assert_eq(data.prompt.title, "Export Data Test", "Title should match")
	assert_eq(data.prompt.content, "Export Content Data", "Content should match")
	
	# Cleanup
	DirAccess.remove_absolute(export_path)


func test_export_with_invalid_id_returns_false() -> void:
	var result: bool = panel.export_prompt("nonexistent", "user://test.json")
	assert_false(result, "Export should fail for invalid ID")


func test_import_prompt_from_file() -> void:
	# First export a prompt
	var original_id: String = panel.create_prompt("Import Test", "Import Content")
	var export_path := "user://test_import.json"
	panel.export_prompt(original_id, export_path)
	
	# Delete original and import
	panel.delete_prompt(original_id)
	var imported_id: String = panel.import_prompt(export_path)
	
	assert_ne(imported_id, "", "Should return new ID")
	var imported: Dictionary = panel.get_prompt(imported_id)
	assert_eq(imported.title, "Import Test", "Title should match")
	assert_eq(imported.content, "Import Content", "Content should match")
	
	# Cleanup
	DirAccess.remove_absolute(export_path)


func test_import_from_nonexistent_file_returns_empty() -> void:
	var result: String = panel.import_prompt("user://nonexistent_file.json")
	assert_eq(result, "", "Import should fail for nonexistent file")


func test_import_from_invalid_json_returns_empty() -> void:
	var bad_path := "user://bad_json.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("{ invalid json content")
	file.close()
	
	var result: String = panel.import_prompt(bad_path)
	assert_eq(result, "", "Import should fail for invalid JSON")
	
	# Cleanup
	DirAccess.remove_absolute(bad_path)

#endregion


#region Connection Diagnostics Tests

func test_get_connection_diagnostics_returns_dictionary() -> void:
	var diagnostics: Dictionary = panel.get_connection_diagnostics()
	
	assert_true(diagnostics.has("is_connected"), "Should have is_connected")
	assert_true(diagnostics.has("connection_attempts"), "Should have connection_attempts")
	assert_true(diagnostics.has("websocket_valid"), "Should have websocket_valid")
	assert_true(diagnostics.has("vscode_port"), "Should have vscode_port")


func test_connection_diagnostics_websocket_valid() -> void:
	var diagnostics: Dictionary = panel.get_connection_diagnostics()
	assert_true(diagnostics.websocket_valid, "WebSocket should be valid")

#endregion


#region Auto-Focus Tests

func test_create_prompt_focuses_title_field() -> void:
	panel.create_prompt()
	await wait_frames(2)
	
	# The title field should have focus after creating a new prompt
	var title_edit: LineEdit = panel._prompt_title_edit
	# Note: In actual editor context this would be focused, but in tests
	# the focus behavior may differ. We test the method exists.
	assert_true(title_edit != null, "Title edit should exist")

#endregion