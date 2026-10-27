extends SceneTree
## Синтетические материалы: проверяем состав/операции, не реальные рецепты.

const DATA := "res://tests/parallel/bar/drink_materials.json"
var _checks: int = 0
var _failures: int = 0
var _catalog := DrinkMaterialCatalog.new()


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _close(a: float, b: float) -> bool:
	return absf(a - b) < 0.000001


func _cup(vessel: StringName = &"test_shot", id: StringName = &"test_cup") -> DrinkPreparation:
	var result := DrinkPreparation.new()
	_expect(result.configure(_catalog, vessel, id), "Configure " + str(id))
	return result


func _run() -> void:
	_expect(_catalog.load_file(DATA), "Load TEST materials")
	_test_catalog()
	_test_invalid_commands()
	_test_layers()
	_test_continuous_layers()
	_test_phases()
	_test_discard_and_seal()
	_test_determinism_and_conservation()
	_test_decimal_boundaries()
	_test_command_limit()
	_test_transfer_and_ice()
	print("%s: drink core, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_transfer_and_ice() -> void:
	var catalog := DrinkMaterialCatalog.new()
	_expect(catalog.load_file("res://content/drinks/test_materials.json"), "Production TEST materials load for vessel tests")
	var source := DrinkPreparation.new()
	var target := DrinkPreparation.new()
	source.configure(catalog, &"test_mixing_glass", &"source_blend")
	target.configure(catalog, &"test_shot", &"target_blend")
	source.pour(&"a", &"test_base", 10)
	source.pour(&"b", &"test_light", 10)
	source.mix(&"stir")
	target.pour(&"base", &"test_heavy", 20)
	for step in 4:
		_expect(not source.transfer_to(StringName("transfer_%d" % step), target, 5, 5, true).is_empty(), "Transfer mixed dose atomically")
	var snapshot := target.get_snapshot()
	_expect(snapshot.layers.size() == 2 and _close(snapshot.layers[1].volume_ml, 20) and snapshot.layers[1].components.test_base == 10 and snapshot.layers[1].components.test_light == 10, "Prepared blend floats as one continuous layer")
	_expect(source.get_volume_ml() == 0 and target.get_volume_ml() == 40 and snapshot.technique.stirred_s > 0, "Transfer conserves liquid and technique provenance")
	var before := target.get_snapshot()
	_expect(source.transfer_to(&"empty", target, 1).is_empty() and target.transfer_to(&"self", target, 1).is_empty() and not target.pour_blend(&"invalid", {"test_base": -1}) and target.get_snapshot() == before, "Invalid composite operations are atomic")
	var receiver := DrinkPreparation.new()
	receiver.configure(catalog, &"test_shot", &"full_receiver")
	receiver.pour(&"fill", &"test_light", 59)
	var before_receiver := receiver.get_snapshot()
	_expect(target.transfer_to(&"overflow", receiver, 2).is_empty() and target.get_snapshot() == before and receiver.get_snapshot() == before_receiver, "Failed receiving capacity preserves both containers")
	var dry := DrinkPreparation.new()
	dry.configure(catalog, &"test_mixing_glass", &"dry_mix")
	dry.pour(&"fill", &"test_base", 50)
	dry.mix(&"dry_shake", &"shake", 10)
	_expect(dry.get_snapshot().technique.temperature_c == 20 and dry.get_snapshot().technique.dilution_ml == 0 and dry.get_snapshot().technique.aeration > 0, "Dry shake aerates but cannot chill or add water")
	var stirred := DrinkPreparation.new()
	var shaken := DrinkPreparation.new()
	stirred.configure(catalog, &"test_mixing_glass", &"iced_stir")
	shaken.configure(catalog, &"test_shaker", &"iced_shake")
	for model in [stirred, shaken]:
		model.pour(&"fill", &"test_base", 50)
		_expect(model.add_ice(&"ice", 40), "Add finite ice to independent container")
	stirred.mix(&"stir", &"stir", 10)
	shaken.mix(&"shake", &"shake", 10)
	var calm := stirred.get_snapshot()
	var rough := shaken.get_snapshot()
	_expect(calm.technique.temperature_c < 20 and calm.technique.dilution_ml > 0 and calm.overall.components.test_water == calm.technique.dilution_ml, "Ice melting adds actual water and lowers temperature")
	_expect(calm.overall.strength < 0.2 and calm.overall.taste.sour < 0.6, "Actual meltwater dilutes strength and taste, not only metadata")
	_expect(rough.technique.temperature_c < calm.technique.temperature_c and rough.technique.aeration > calm.technique.aeration and rough.technique.dilution_ml > calm.technique.dilution_ml, "Equal stirring and shaking time produce different texture and cooling")
	_expect(_close(calm.overall.volume_ml + calm.technique.ice_ml, 90) and _close(rough.overall.volume_ml + rough.technique.ice_ml, 90), "Ice melt conserves liquid plus remaining ice")
	var receiving := DrinkPreparation.new()
	receiving.configure(catalog, &"test_glass", &"strained_mix")
	var remaining_ice: float = rough.technique.ice_ml
	_expect(not shaken.transfer_to(&"strain", receiving, shaken.get_volume_ml()).is_empty() and shaken.get_snapshot().technique.ice_ml == remaining_ice and receiving.get_snapshot().technique.ice_ml == 0, "Straining leaves ice in source while transferring liquid")
	_expect(receiving.get_snapshot().technique.shaken_s == 10 and _close(receiving.get_snapshot().technique.dilution_ml, rough.technique.dilution_ml), "Strained result retains real dilution and shaking history")
	_expect(shaken.empty_container(&"sink") and shaken.get_snapshot().technique.ice_ml == 0, "Sink removes spent ice too")
	var final := receiving.seal(&"serve")
	_expect(not final.is_empty() and not receiving.add_ice(&"late_ice") and receiving.extract(&"late_extract", 1).is_empty() and not receiving.empty_container(&"late_empty"), "Serving seals all new mutating paths")
	var two := DrinkPreparation.new()
	two.configure(catalog, &"test_glass", &"repeat_target")
	target.transfer_to(&"once", two, 10)
	var frozen_source := target.get_snapshot()
	var frozen_target := two.get_snapshot()
	_expect(target.transfer_to(&"once", two, 10).is_empty() and target.get_snapshot() == frozen_source and two.get_snapshot() == frozen_target, "Transfer command cannot duplicate a dose")
	var fizzy := DrinkPreparation.new()
	fizzy.configure(catalog, &"test_shaker", &"fizzy_mix")
	fizzy.pour(&"soda", &"test_soda", 20)
	var carbonated := fizzy.get_snapshot()
	_expect(not fizzy.mix(&"shake", &"shake") and fizzy.get_snapshot() == carbonated and fizzy.mix(&"stir", &"stir"), "Carbonated ingredients are built or gently stirred, not shaken")
	stirred.pour(&"float_light", &"test_light", 20, 5, true)
	var top_only := DrinkPreparation.new()
	top_only.configure(catalog, &"test_shot", &"top_only")
	stirred.transfer_to(&"skim", top_only, 10, 5, true)
	_expect(top_only.get_snapshot().technique.dilution_ml == 0 and _close(stirred.get_snapshot().technique.dilution_ml, calm.technique.dilution_ml), "Removing dry top layer cannot steal dilution from lower layer")
	var view := stirred.get_view()
	view.layers.clear()
	_expect(not stirred.get_view().layers.is_empty() and not stirred.get_view().has("operations"), "Lightweight render view is isolated and omits growing command history")
	var phases := DrinkPreparation.new()
	var phase_target := DrinkPreparation.new()
	phases.configure(catalog, &"test_mixing_glass", &"separate_phases")
	phase_target.configure(catalog, &"test_glass", &"phase_target")
	phases.pour(&"water_base", &"test_base", 20)
	phases.pour(&"oil", &"test_oil", 10)
	phases.transfer_to(&"pour_phases", phase_target, 30)
	_expect(phase_target.get_snapshot().layers.size() == 2 and not phase_target.get_snapshot().overall.emulsified, "Pouring separate phases cannot create a shaken emulsion")
	phase_target.mix(&"emulsify", &"shake")
	phases.empty_container(&"clear_ice")
	phase_target.transfer_to(&"emulsified_pour", phases, 30)
	_expect(phases.get_snapshot().structure == "emulsified", "Transfer preserves an actual shaken emulsion")


func _test_catalog() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var broken := DrinkMaterialCatalog.new()
	_expect(not broken.load_file("res://tests/parallel/bar/missing_drink_materials.json"), "Missing catalog rejected")
	_expect(not broken.load_document(null) and not broken.load_document([]), "Non-object catalog rejected")
	for kind in ["version", "bool_version", "empty", "null", "duplicate", "missing", "extra", "id", "title", "density", "nan", "bool_number", "viscosity", "strength", "color", "color_range", "taste", "tags", "duplicate_tag", "mix_group", "vessel", "vessel_duplicate", "vessel_bool"]:
		var data := original.duplicate(true)
		match kind:
			"version": data.schema_version = 2
			"bool_version": data.schema_version = true
			"empty": data.ingredients = []
			"null": data.ingredients[0] = null
			"duplicate": data.ingredients.append(data.ingredients[0].duplicate(true))
			"missing": data.ingredients[0].erase("density")
			"extra": data.ingredients[0].price = 10
			"id": data.ingredients[0].id = "Bad ID"
			"title": data.ingredients[0].title = " "
			"density": data.ingredients[0].density = -1
			"nan": data.ingredients[0].density = NAN
			"bool_number": data.ingredients[0].density = true
			"viscosity": data.ingredients[0].viscosity = 1.1
			"strength": data.ingredients[0].strength = -0.1
			"color": data.ingredients[0].color = [1, 0]
			"color_range": data.ingredients[0].color[0] = INF
			"taste": data.ingredients[0].taste.salty = 1
			"tags": data.ingredients[0].tags = [2]
			"duplicate_tag": data.ingredients[0].tags = ["test_tag", "test_tag"]
			"mix_group": data.ingredients[0].mix_group = ""
			"vessel": data.vessels[0].capacity_ml = 0
			"vessel_duplicate": data.vessels.append(data.vessels[0].duplicate(true))
			"vessel_bool": data.vessels[0].capacity_ml = true
		var catalog := DrinkMaterialCatalog.new()
		_expect(not catalog.load_document(data) and not catalog.validation_errors.is_empty(), "Reject catalog " + kind)
		_expect(not catalog.is_loaded() and catalog.get_ingredient_ids().is_empty() and catalog.get_vessel_ids().is_empty(), "No partial catalog " + kind)
	_expect(broken.load_document(original), "Retry after invalid catalog")
	original.ingredients[0].density = 9
	var ingredient := broken.get_ingredient(&"test_heavy")
	ingredient.color[0] = 0
	_expect(_close(broken.get_ingredient(&"test_heavy").density, 1.3) and broken.get_ingredient(&"test_heavy").color[0] == 1, "Source and getter copies isolated")
	var vessel := broken.get_vessel(&"test_shot")
	vessel.capacity_ml = 999
	_expect(broken.get_vessel(&"test_shot").capacity_ml == 60 and not broken.load_document(original), "Catalog immutable after successful load")
	_expect(broken.get_ingredient(&"missing").is_empty() and broken.get_vessel(&"missing").is_empty() and broken.is_test_content(), "Unknown IDs empty and TEST flag retained")


func _test_invalid_commands() -> void:
	var cup := DrinkPreparation.new()
	_expect(cup.get_snapshot().is_empty() and cup.get_result().is_empty() and cup.get_volume_ml() == 0, "Unconfigured getters safe")
	_expect(not cup.pour(&"a", &"test_base", 10) and not cup.mix(&"b") and not cup.settle(&"c") and not cup.discard(&"d", 10) and cup.seal(&"e").is_empty(), "Unconfigured commands rejected")
	_expect(not cup.configure(DrinkMaterialCatalog.new(), &"test_shot", &"cup") and not cup.configure(_catalog, &"missing", &"cup") and not cup.configure(_catalog, &"test_shot", &"Bad ID"), "Bad configure rejected")
	_expect(cup.configure(_catalog, &"test_shot", &"test_invalid_cup"), "Valid retry configures cup")
	var before := cup.get_snapshot()
	_expect(not cup.mix(&"empty") and not cup.settle(&"empty") and not cup.discard(&"empty", 1) and cup.seal(&"empty").is_empty(), "Empty actions rejected")
	for amount in [0.0, -1.0, NAN, INF, 61.0]:
		_expect(not cup.pour(&"invalid_amount", &"test_base", amount) and cup.get_snapshot() == before, "Invalid/overflow amount atomic")
	for flow in [0.0, -1.0, NAN, INF, 501.0]:
		_expect(not cup.pour(&"invalid_flow", &"test_base", 10, flow) and cup.get_snapshot() == before, "Invalid flow atomic")
	_expect(not cup.pour(&"bad id", &"test_base", 10) and not cup.pour(&"missing", &"unknown", 10), "Unknown ingredient or bad command ID")
	_expect(cup.pour(&"invalid_amount", &"test_base", 60), "Failed command ID can be retried with valid amount")
	before = cup.get_snapshot()
	_expect(not cup.pour(&"invalid_amount", &"test_light", 1) and not cup.mix(&"invalid_amount"), "Command ID unique across operation types")
	_expect(not cup.pour(&"overflow", &"test_light", 1) and not cup.mix(&"unknown_method", &"blend") and not cup.configure(_catalog, &"test_glass", &"new_cup") and cup.get_snapshot() == before, "Rejected commands preserve full cup")


func _layered_cup() -> DrinkPreparation:
	var cup := _cup()
	_expect(cup.pour(&"heavy", &"test_heavy", 20), "Pour dense base")
	_expect(cup.pour(&"base", &"test_base", 20, 5, true), "Gently layer middle")
	_expect(cup.pour(&"light", &"test_light", 20, 5, true), "Gently layer light top")
	return cup


func _test_layers() -> void:
	var cup := _layered_cup()
	var state := cup.get_snapshot()
	_expect(state.structure == "layered" and state.layers.size() == 3 and _close(cup.get_volume_ml(), 60), "Three ordered layers in shot")
	_expect(_close(state.layers[0].density, 1.3) and _close(state.layers[1].density, 1) and _close(state.layers[2].density, 0.8), "Layers stored bottom to top")
	_expect(_close(state.overall.strength, 0.8 / 3) and _close(state.overall.color[0], 1.0 / 3) and _close(state.overall.taste.sweet, 1.0 / 3), "Profile and color weighted by actual portions")
	_expect(cup.mix(&"stir"), "Stir layered shot")
	_expect(cup.get_snapshot().structure == "homogeneous" and cup.get_snapshot().overall == state.overall, "Stir destroys compatible layers without changing composition")
	var fast := _cup()
	fast.pour(&"first", &"test_heavy", 20)
	fast.pour(&"fast", &"test_base", 20, 100, true)
	_expect(fast.get_snapshot().layers.size() == 1 and fast.get_snapshot().operations[1].data.outcome == "mixed_pour", "Fast pour destroys intended layer")
	var reversed := _cup()
	reversed.pour(&"light", &"test_light", 20)
	reversed.pour(&"heavy", &"test_heavy", 20, 1, true)
	_expect(reversed.get_snapshot().structure == "homogeneous", "Dense pour on light base mixes rather than sorting into perfect layers")
	var equal := _cup()
	equal.pour(&"first", &"test_heavy", 20)
	equal.pour(&"same_density", &"test_equal", 20, 1, true)
	_expect(equal.get_snapshot().layers.size() == 1, "Equal density does not create fake boundary")
	var viscous := _cup()
	viscous.pour(&"first", &"test_heavy", 10)
	viscous.pour(&"second", &"test_base", 10, 20, true)
	var runny := _cup()
	runny.pour(&"first", &"test_equal", 10)
	runny.pour(&"second", &"test_base", 10, 20, true)
	_expect(viscous.get_snapshot().layers.size() == 2 and runny.get_snapshot().layers.size() == 1, "Viscosity changes allowable layering flow in game model")


func _test_continuous_layers() -> void:
	var cup := _cup()
	cup.pour(&"heavy", &"test_heavy", 20)
	for index in 20:
		_expect(cup.pour(StringName("dose_%d" % index), &"test_base", 0.5, 5, true), "Continuous dose accepted")
	var result := cup.get_snapshot()
	_expect(result.layers.size() == 2 and result.layers[0].volume_ml == 20 and result.layers[1].volume_ml == 10, "Successive gentle doses extend top layer without mixing lower one")
	_expect(result.operations[-1].data.outcome == "layer_extended", "Layer extension recorded in history")
	cup.pour(&"fast", &"test_base", 1, 100, true)
	_expect(cup.get_snapshot().structure == "homogeneous", "Fast continuous dose can still destroy layers")


func _test_phases() -> void:
	var cup := _cup(&"test_glass")
	cup.pour(&"base", &"test_base", 60)
	cup.pour(&"phase", &"test_oil", 30)
	var before := cup.get_snapshot()
	_expect(before.structure == "layered" and not before.overall.emulsified and _close(before.layers[0].density, 1), "Separate phases stay separate under normal pour")
	_expect(cup.mix(&"shake", &"shake") and cup.get_snapshot().structure == "emulsified", "Shaking combines incompatible phases temporarily")
	cup.pour(&"more", &"test_base", 30)
	_expect(cup.get_snapshot().structure == "emulsified" and _close(cup.get_volume_ml(), 120), "Adding to emulsion keeps it until settling")
	_expect(cup.settle(&"rest") and cup.get_snapshot().structure == "layered", "Explicit rest separates phases")
	var after := cup.get_snapshot()
	_expect(_close(after.layers[0].volume_ml, 90) and _close(after.layers[1].volume_ml, 30) and not after.overall.emulsified, "Settling retains components and phase volumes")
	_expect(after.overall.tags == ["test_base_tag", "test_phase_tag"], "Metadata tags deterministic and combined without applying effects")
	cup.pour(&"marker", &"test_trace", 1)
	_expect("test_additive" in cup.get_snapshot().overall.tags and _close(cup.get_snapshot().overall.components.test_trace, 1), "Marker remains real component for future reactions")


func _test_discard_and_seal() -> void:
	var cup := _layered_cup()
	_expect(cup.discard(&"top_partial", 5), "Discard part of top layer")
	var snapshot := cup.get_snapshot()
	_expect(_close(snapshot.layers[2].volume_ml, 15) and _close(snapshot.layers[0].volume_ml, 20) and _close(cup.get_volume_ml(), 55), "Top drain preserves lower layers")
	_expect(cup.discard(&"across", 25) and cup.get_snapshot().layers.size() == 2 and _close(cup.get_snapshot().layers[1].volume_ml, 10), "Drain can cross layer boundary")
	cup.mix(&"stir")
	var before: Dictionary = cup.get_snapshot().overall
	cup.discard(&"half", 15)
	var after: Dictionary = cup.get_snapshot().overall
	_expect(_close(after.components.test_heavy, 10) and _close(after.components.test_base, 5) and _close(after.strength, before.strength), "Draining mixture retains proportions and concentration")
	var unchanged := cup.get_snapshot()
	for amount in [0.0, -1.0, NAN, INF, 16.0]:
		_expect(not cup.discard(&"invalid", amount) and cup.get_snapshot() == unchanged, "Invalid drain atomic")
	var result := cup.seal(&"serve")
	_expect(result.sealed and result.test_content and result.event_id == "drink:test_cup:serve", "Sealed result scoped to preparation and command")
	result.layers[0].components.test_heavy = 999
	result.operations[0].data.volume_ml = 999
	result.vessel.capacity_ml = 999
	_expect(_close(cup.get_result().overall.volume_ml, 15) and _close(cup.get_result().layers[0].components.test_heavy, 10) and cup.get_result().vessel.capacity_ml == 60, "Sealed result is isolated deep snapshot")
	unchanged = cup.get_snapshot()
	_expect(cup.seal(&"serve").is_empty() and cup.seal(&"again").is_empty() and not cup.mix(&"change") and not cup.pour(&"more", &"test_base", 1) and not cup.settle(&"rest") and not cup.discard(&"empty", 15), "All mutating commands rejected after seal")
	_expect(cup.get_snapshot() == unchanged and cup.get_result().revision == unchanged.revision, "Sealed state and operation count stable")
	var empty := _cup()
	empty.pour(&"a", &"test_base", 20)
	_expect(empty.discard(&"empty", 20) and empty.get_snapshot().structure == "empty" and empty.get_snapshot().overall.tags.is_empty(), "Full drain clears composition and tags")
	_expect(empty.pour(&"refill", &"test_light", 5), "Discarded cup can be refilled")


func _test_determinism_and_conservation() -> void:
	var first := _cup(&"test_glass", &"test_replay")
	var second := _cup(&"test_glass", &"test_replay")
	var expected: Dictionary = {}
	var random := RandomNumberGenerator.new()
	random.seed = 72149
	var ids := _catalog.get_ingredient_ids()
	for index in 70:
		var id := StringName(ids[random.randi_range(0, ids.size() - 1)])
		var volume := random.randi_range(1, 12) / 4.0
		var flow := float(random.randi_range(1, 80))
		var layered := random.randf() > 0.5
		var command := StringName("pour_%d" % index)
		for cup in [first, second]:
			_expect(cup.pour(command, id, volume, flow, layered), "Replay pour accepted")
		expected[str(id)] = float(expected.get(str(id), 0)) + volume
		if index % 7 == 0:
			var method: StringName = &"stir" if index % 2 == 0 else &"shake"
			for cup in [first, second]:
				cup.mix(StringName("mix_%d" % index), method)
		var state := first.get_snapshot()
		_expect(state == second.get_snapshot(), "Same command sequence produces same snapshot")
		var total := 0.0
		for ingredient in expected:
			total += float(expected[ingredient])
			_expect(_close(state.overall.components[ingredient], expected[ingredient]), "Every component conserved across mixing")
		var layers_total := 0.0
		for layer in state.layers:
			layers_total += float(layer.volume_ml)
		_expect(_close(total, first.get_volume_ml()) and _close(total, layers_total), "Layer and overall volume conserved")
	var copy := first.get_snapshot()
	copy.layers.clear()
	copy.overall.components.clear()
	_expect(not first.get_snapshot().layers.is_empty() and first.get_snapshot().overall.components == expected, "Draft snapshot does not expose internal state")


func _test_decimal_boundaries() -> void:
	var cup := _cup()
	for index in 600:
		if not cup.pour(StringName("drop_%d" % index), &"test_base", 0.1):
			_expect(false, "Decimal doses must fill capacity without rounding rejection")
			return
	_expect(_close(cup.get_volume_ml(), 60) and cup.get_volume_ml() <= 60, "Decimal dosing stays inside capacity")
	_expect(cup.discard(&"drain", 60) and cup.get_volume_ml() == 0, "Decimal cup can be emptied completely")
	_expect(not cup.pour(&"too_small", &"test_base", 0.00001), "Sub-resolution dose rejected")
	var rounded := _cup()
	_expect(rounded.pour(&"rounding", &"test_base", 60.0000001) and rounded.get_volume_ml() == 60, "Only numerical epsilon may be trimmed to capacity")
	_expect(_close(rounded.get_snapshot().operations[0].data.volume_ml, 60), "Operation records actual accepted dose")


func _test_command_limit() -> void:
	var cup := _cup()
	cup.pour(&"first", &"test_base", 1)
	for index in DrinkPreparation.MAX_COMMANDS - 1:
		if not cup.mix(StringName("stir_%d" % index)):
			_expect(false, "Command limit reached too early")
			return
	_expect(not cup.mix(&"overflow") and cup.get_snapshot().revision == DrinkPreparation.MAX_COMMANDS, "Bounded command history")
	_expect(not cup.seal(&"final").is_empty() and cup.get_result().revision == DrinkPreparation.MAX_COMMANDS + 1, "Final sealing remains available at history limit")
