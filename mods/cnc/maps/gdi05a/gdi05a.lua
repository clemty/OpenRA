-- This is a heavily annotated mission script to illustrate the way OpenRA missions are scripted.
--
-- Lua scripts are only parsed after map.yaml, so if you haven't taken a look at map.yaml, we recommend to
-- start there.
--
-- Comments in Lua begin with two dashes ("--") and end at the end of the line.
-- Alternatively, sections may be commented out using "--[[" and "]]--".
--
-- The Lua file is parsed completely before execution, so it does not matter if variables are defined before
-- or after script functions. Variables are global (may be used from anywhere in the file), unless explicitly
-- marked as local.
--
-- Execution starts at "WorldLoaded = function()".
-- Additionally, the code after "Tick = function()" is called 25 times/second on normal game speed.
--
-- If there is a crash during Lua execution, the error is logged to OpenRa/logs/lua.log
-- To aid debugging, Lua code may also be checked statically using the 'make' script.
--
-- The actual code begins below:

-- Difficulty-related variables: when the health of a structure drops beneath 30%, 60%, 90%,
-- the AI will begin to repair it. RepairThreshold is an arbitrary variable name and not a reserved keyword.
-- "Easy", "Normal" and "Hard" are the (also arbitrary) difficulty strings defined in map.yaml.
RepairThreshold = { Easy = 0.3, Normal = 0.6, Hard = 0.9 }

-- All units are present on the map (as placed within the OpenRA editor). To make the mission easier, define
-- an array of units ("actors") which are removed upon mission start.
-- Actor[number] are defined in map.yaml.
-- ActorRemovals is an arbitrary variable name and not a reserved keyword; the actual removing of actors is
-- performed later.
ActorRemovals =
{
	Easy = { Actor167, Actor168, Actor190, Actor191, Actor193, Actor194, Actor196, Actor198, Actor200 },
	Normal = { Actor167, Actor194, Actor196, Actor197 },
	Hard = { },
}

-- Define arrays (groups of units and structures) for easier reference.
-- Values without quotation marks/apostrophes are names defined in map.yaml or variables defined in Lua code.
-- Values inside quotation marks (") or apostrophes (') are reserved names (tooltips in the OpenRA editor
-- show units/structures and their corresponding reserved names).

-- The three arrays with units below define the starting units the player has.
-- "mtank" = Medium Tank
-- "apc" = APC troop transport
-- "e1" = rifle infantry
-- "e2" = rocket soldier
GdiTanks = { "mtnk", 'mtnk' }
GdiApc = { "apc" }
GdiInfantry = { "e1", "e1", "e1", "e1", "e1", "e2", "e2", "e2", "e2", "e2" }

-- For debugging purposes it may be useful to have a stronger initial force;
-- uncomment the following line to replace the two Medium Tanks with four Mammoth Tanks ("htnk"), then
-- (re)start the mission to see the changes.
--GdiTanks = { "htnk", "htnk", "htnk", "htnk" }

-- Define groups of buildings which are referenced later for mission objectives
-- GdiBase: buildings which are assigned to the player once the player's units enter the base
-- NodSams: Nod SAM sites which need to be destroyed to receive air strike support

GdiBase = { GdiNuke1, GdiNuke2, GdiProc, GdiSilo1, GdiSilo2, GdiPyle, GdiWeap, GdiHarv }
NodSams = { Sam1, Sam2, Sam3, Sam4 }

-- The following section defines settings for two Nod patrols:
-- "bggy" = Nod buggy
-- waypointX variables are defined in map.yaml.
-- the .Location is a property (trait) of the waypoint and a reserved keyword
Grd1UnitTypes = { "bggy" }
Grd1Path = { waypoint4.Location, waypoint5.Location, waypoint10.Location }
Grd1Delay = { Easy = DateTime.Minutes(2), Normal = DateTime.Minutes(1), Hard = DateTime.Seconds(30) }

Grd2UnitTypes = { "bggy" }
Grd2Path = { waypoint0.Location, waypoint1.Location, waypoint2.Location }
Grd3Units = { GuardTank1, GuardTank2 }
Grd3Path = { waypoint4.Location, waypoint5.Location, waypoint9.Location }

-- The next section contains settings for AI attacks on the player
AttackDelayMin = { Easy = DateTime.Minutes(1), Normal = DateTime.Seconds(45), Hard = DateTime.Seconds(30) }
AttackDelayMax = { Easy = DateTime.Minutes(2), Normal = DateTime.Seconds(90), Hard = DateTime.Minutes(1) }
AttackUnitTypes =
{
	Easy =
	{
		{ factory = HandOfNod, types = { "e1", "e1" } },
		{ factory = HandOfNod, types = { "e1", "e3" } },
		{ factory = HandOfNod, types = { "e1", "e1", "e3" } },
		{ factory = HandOfNod, types = { "e1", "e3", "e3" } },
	},
	Normal =
	{
		{ factory = HandOfNod, types = { "e1", "e1", "e3" } },
		{ factory = HandOfNod, types = { "e1", "e3", "e3" } },
		{ factory = HandOfNod, types = { "e1", "e1", "e3", "e3" } },
		{ factory = Airfield, types = { "bggy" } },
	},
	Hard =
	{
		{ factory = HandOfNod, types = { "e1", "e1", "e3", "e3" } },
		{ factory = HandOfNod, types = { "e1", "e1", "e1", "e3", "e3" } },
		{ factory = HandOfNod, types = { "e1", "e1", "e3", "e3", "e3" } },
		{ factory = Airfield, types = { "bggy" } },
		{ factory = Airfield, types = { "ltnk" } },
	}
}
AttackPaths =
{
	{ waypoint0.Location, waypoint1.Location, waypoint2.Location, waypoint3.Location },
	{ waypoint4.Location, waypoint9.Location, waypoint7.Location, waypoint8.Location },
}

-- Script execution starts here:
WorldLoaded = function()
	-- Assign variable names to the players defined in map.yaml.
	gdiBase = Player.GetPlayer("AbandonedBase")
	player = Player.GetPlayer("GDI")
	enemy = Player.GetPlayer("Nod")

	-- Set up triggers which are executed when a specific condition is met.
	-- The following section notifies the player that a objectives are added, completed or failed.
	-- Valid triggers are listed under 'Trigger' in the OpenRA Lua api documentation.
	Trigger.OnObjectiveAdded(player, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "New " .. string.lower(p.GetObjectiveType(id)) .. " objective")
	end)
	Trigger.OnObjectiveCompleted(player, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "Objective completed")
	end)
	Trigger.OnObjectiveFailed(player, function(p, id)
		Media.DisplayMessage(p.GetObjectiveDescription(id), "Objective failed")
	end)

	-- Play a sound sample ("Your mission is a failure") if the mission is lost. Valid variables are defined in
	-- mods/cnc/audio/notifications.yaml
	Trigger.OnPlayerLost(player, function()
		Media.PlaySpeechNotification(player, "Lose")
	end)

	Trigger.OnPlayerWon(player, function()
		Media.PlaySpeechNotification(player, "Win")
	end)

	-- Add initial mission objectives. Setting objectives for the enemy is not strictly needed, but makes the
	-- mission code more readable.
	nodObjective = enemy.AddPrimaryObjective("Destroy all GDI troops.")
	gdiObjective1 = player.AddPrimaryObjective("Find the GDI base.")
	gdiObjective2 = player.AddSecondaryObjective("Destroy all SAM sites to receive air support.")

	SetupWorld()

	-- Set the initial viewpoint. 'GdiTankRallyPoint' is a waypoint defined in map.yaml.
	Camera.Position = GdiTankRallyPoint.CenterPosition
end

SetupWorld = function()
	-- Remove actors from the map depending on the selected difficulty level.
	-- .Destroy() is a reserved function name and removes a unit/structure from the map without killing it.
	Utils.Do(ActorRemovals[Map.Difficulty], function(unit)
		unit.Destroy()
	end)

	-- Play a sound sample ("Reinforcements have arrived") to a specific player.
	Media.PlaySpeechNotification(player, "Reinforce")

	-- Send initial units into the map. While it is possible to just place them on the map using the editor,
	-- having them move into the map is preferred since it looks more polished.
	Reinforcements.Reinforce(player, GdiTanks, { GdiTankEntry.Location, GdiTankRallyPoint.Location }, DateTime.Seconds(1), function(actor) actor.Stance = "Defend" end)
	Reinforcements.Reinforce(player, GdiApc, { GdiApcEntry.Location, GdiApcRallyPoint.Location }, DateTime.Seconds(1), function(actor) actor.Stance = "Defend" end)
	Reinforcements.Reinforce(player, GdiInfantry, { GdiInfantryEntry.Location, GdiInfantryRallyPoint.Location }, 15, function(actor) actor.Stance = "Defend" end)

	-- Set up a trigger to turn over control to the abandoned GDI base once the player discovers any of the
	-- structures/units defined in the 'gdiBase' array.
	-- DiscoverGdiBase is a function defined further below (note that functions without arguments can be either
	-- called with or without parantheses - "DiscoverGdiBase()" or "DiscoverGdiBase" both work).
	Trigger.OnPlayerDiscovered(gdiBase, DiscoverGdiBase)

	-- Tell the AI to repair its buildings if they are damaged by the player:
	-- Iterate through all actors defined in map.yaml, if they are controlled by Nod and can repair themselves
	-- set up a trigger on each of them which starts repairs if the building health falls beneath a threshold
	-- depending on the difficulty level.
	Utils.Do(Map.NamedActors, function(actor)
		if actor.Owner == enemy and actor.HasProperty("StartBuildingRepairs") then
			Trigger.OnDamaged(actor, function(building)
				if building.Owner == enemy and building.Health < RepairThreshold[Map.Difficulty] * building.MaxHealth then
					building.StartBuildingRepairs()
				end
			end)
		end
	end)

	-- Enable the Airstrike once all SAM sites are destroyed
	Trigger.OnAllKilled(NodSams, function()
		player.MarkCompletedObjective(gdiObjective2)
		Actor.Create("airstrike.proxy", true, { Owner = player })
	end)

	-- Tell the GDI harvester at the not-yet-discovered base to not harvest Tiberium until it is controlled by
	-- the player.
	GdiHarv.Stop()

	-- Tell the Nod harvester to start collecting Tiberium.
	NodHarv.FindResources()

	-- If difficulty is "Easy", the AI does not retaliate if the Nod harvester is attacked.
	-- On "Medium", all mobile Nod units will move towards the harvester, attacking any GDI units on the way
	-- there (".Attackmove()").
	-- On "Hard", all mobile Nod units will also move towards the harvester, but they will also attack any of
	-- the player's units or structures (".Hunt()") after arriving there.
	if Map.Difficulty ~= "Easy" then
		Trigger.OnDamaged(NodHarv, function()
			Utils.Do(enemy.GetGroundAttackers(), function(unit)
				unit.AttackMove(NodHarv.Location)
				if Map.Difficulty == "Hard" then
					unit.Hunt()
				end
			end)
		end)
	end

	-- Start the three Nod patrols, the first after 45 seconds, the second after 3 minutes, the third
	-- immediately.
	Trigger.AfterDelay(DateTime.Seconds(45), Grd1Action)
	Trigger.AfterDelay(DateTime.Minutes(3), Grd2Action)
	Grd3Action()
end

-- This function builds units for an attack.
Build = function(factory, units, action)
	if factory.IsDead or factory.Owner ~= enemy then
		return
	end

	if not factory.Build(units, action) then
		Trigger.AfterDelay(DateTime.Seconds(5), function()
			Build(factory, units, action)
		end)
	end
end

-- Build a random attack force and send it towards the player on a random route.
Attack = function()
	local production = Utils.Random(AttackUnitTypes[Map.Difficulty])
	local path = Utils.Random(AttackPaths)
	Build(production.factory, production.types, function(units)
		Utils.Do(units, function(unit)
			if unit.Owner ~= enemy then return end
			unit.Patrol(path, false)
			Trigger.OnIdle(unit, unit.Hunt)
		end)
	end)

	-- The AfterDelay trigger only fires once; to create another attack, the trigger sets up another trigger.
	Trigger.AfterDelay(Utils.RandomInteger(AttackDelayMin[Map.Difficulty], AttackDelayMax[Map.Difficulty]), Attack)
end

Grd1Action = function()
	Build(Airfield, Grd1UnitTypes, function(units)
		Utils.Do(units, function(unit)
			if unit.Owner ~= enemy then return end
			Trigger.OnKilled(unit, function()
				Trigger.AfterDelay(Grd1Delay[Map.Difficulty], Grd1Action)
			end)
			unit.Patrol(Grd1Path, true, DateTime.Seconds(7))
		end)
	end)
end

Grd2Action = function()
	Build(Airfield, Grd2UnitTypes, function(units)
		Utils.Do(units, function(unit)
			if unit.Owner ~= enemy then return end
			unit.Patrol(Grd2Path, true, DateTime.Seconds(5))
		end)
	end)
end

Grd3Action = function()
	local unit
	for i, u in ipairs(Grd3Units) do
		if not u.IsDead then
			unit = u
			break
		end
	end

	if unit ~= nil then
		Trigger.OnKilled(unit, function()
			Grd3Action()
		end)

		unit.Patrol(Grd3Path, true, DateTime.Seconds(11))
	end
end

-- This function is executed once any actor discovers any of the structures defined in the GdiBase variable.
-- (Execution is set up by "Trigger.OnPlayerDiscovered" above)
DiscoverGdiBase = function(actor, discoverer)
	-- if the base is already discovered, do nothing
	-- if the base is discovered by the AI, do nothing
	if baseDiscovered or not discoverer == player then
		return
	end

	-- Assign ownership of the buildings to the player (until now they belong to the AI player 'AbandonedBase').
	-- Utils.Do is a reserved function name which executes the following function for every actor in the list
	-- 'GdiBase'.
	-- .Owner is a trait and defines which player can control an actor
	Utils.Do(GdiBase, function(actor)
		actor.Owner = player
	end)

	-- Tell the GDI harvester to start harvesting Tiberium.
	-- GdiHarv is defined in the .yaml file
	-- .FindResources() is a reserved function name
	GdiHarv.FindResources()

	-- This is set so that the player can only discover the base once.
	-- In Lua, undefined variables are evaluated as 'false', so the variable is not initialized with 'false'
	-- before.
	baseDiscovered = true

	-- Add a new primary objective
	gdiObjective3 = player.AddPrimaryObjective("Eliminate all Nod forces in the area.")
	-- Mark the first primary objective ("Find the GDI base.") as completed.
	-- Note that first a new primary objective is added, and then the previous primary objective is marked as
	-- completed.
	-- If the order of the functions were reversed, the mission would immediately end since at that point all
	-- primary objectives are completed.
	player.MarkCompletedObjective(gdiObjective1)
	
	-- Send an AI attack towards the player (the function is defined above).
	Attack()
end

-- Tick is called 25 times/second on normal game speed.
Tick = function()
	-- Check if the player has lost. Note that the check is first executed after 2 ticks because the player
	-- has to move his units into the map first. Checking this at mission start would lead to an instant
	-- victory for Nod.
	if player.HasNoRequiredUnits() then
		if DateTime.GameTime > 2 then
			enemy.MarkCompletedObjective(nodObjective)
		end
	end
	-- Check if all Nod units have been destroyed.
	if baseDiscovered and enemy.HasNoRequiredUnits() then
		player.MarkCompletedObjective(gdiObjective3)
	end
end
