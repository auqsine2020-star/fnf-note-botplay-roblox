--[[
	FNF-style Botplay (Auto-hit) Script for Roblox
	------------------------------------------------
	This is a GENERIC TEMPLATE. Every Roblox FNF fan game structures its
	notes, receptors, and hit-detection differently, so you WILL need to
	edit the config section below to match your target game's actual
	instance names/paths.

	How it works:
	1. It watches a folder of falling "Note" parts (or a note-tracks table).
	2. For each note, it calculates when the note's position lines up with
	   the receptor ("hit window").
	3. At that moment, it simulates the correct key input (via
	   VirtualInputManager, UserInputService-style event firing, or by
	   directly calling the game's own "OnNoteHit" RemoteEvent/BindableEvent
	   if one exists — direct RemoteEvent calls are far more reliable than
	   simulated key presses).

	IMPORTANT: Only use this in single-player / practice contexts, or in
	games where scripted autoplay is explicitly allowed. Many multiplayer
	games treat this as cheating and may ban you for using it.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

--=====================================================================
-- CONFIG — edit these to match the game you're running this in
--=====================================================================
local CONFIG = {
	-- Folder/instance where active falling notes live. Common patterns:
	-- workspace.Notes, ReplicatedStorage.ActiveNotes, PlayerGui.Game.Notes, etc.
	NotesContainerPath = workspace:FindFirstChild("Notes"),

	-- Each note instance is expected to have some way to tell which lane
	-- it belongs to (an IntValue, an attribute, or part of its Name).
	-- Adjust GetLaneFromNote() below to match.
	LaneKeys = {
		[1] = Enum.KeyCode.D,
		[2] = Enum.KeyCode.F,
		[3] = Enum.KeyCode.J,
		[4] = Enum.KeyCode.K,
	},

	-- Y position (studs) that counts as "in the hit window" — tweak per game.
	HitWindowY = 5,

	-- If the game exposes a RemoteEvent for note hits, prefer firing that
	-- directly instead of simulating keypresses (far more reliable).
	-- Example: ReplicatedStorage.Remotes.NoteHit
	NoteHitRemote = nil, -- set this if you find the remote, e.g.:
	-- ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NoteHit"),

	-- How often (seconds) to poll for notes entering the hit window.
	PollInterval = 0, -- 0 = every frame via RenderStepped
}

--=====================================================================
-- Helpers
--=====================================================================

-- Figure out which lane (1-4) a note belongs to.
-- EDIT THIS to match how your game marks lanes.
local function GetLaneFromNote(note)
	-- Option A: an IntValue/attribute called "Lane"
	local laneAttr = note:GetAttribute("Lane")
	if laneAttr then
		return laneAttr
	end

	local laneValue = note:FindFirstChild("Lane")
	if laneValue and laneValue:IsA("IntValue") then
		return laneValue.Value
	end

	-- Option B: encoded in the note's name, e.g. "Note_2"
	local numFromName = note.Name:match("Note_(%d)")
	if numFromName then
		return tonumber(numFromName)
	end

	return nil
end

-- Get the note's current Y position, however it's parented.
local function GetNoteY(note)
	if note:IsA("BasePart") then
		return note.Position.Y
	elseif note:IsA("Model") and note.PrimaryPart then
		return note.PrimaryPart.Position.Y
	end
	return nil
end

local hitNotes = {} -- track notes we've already triggered, so we don't double-hit

local function SimulateKeyTap(keyCode)
	VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
	task.wait(0.03)
	VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function HitNote(note, lane)
	if hitNotes[note] then
		return
	end
	hitNotes[note] = true

	if CONFIG.NoteHitRemote then
		-- Preferred path: tell the game directly that this note was hit.
		CONFIG.NoteHitRemote:FireServer(note, lane)
	else
		-- Fallback: simulate the actual key press for this lane.
		local key = CONFIG.LaneKeys[lane]
		if key then
			task.spawn(SimulateKeyTap, key)
		end
	end

	-- Clean up tracking once the note is gone, to avoid a growing table.
	task.delay(2, function()
		hitNotes[note] = nil
	end)
end

--=====================================================================
-- Main loop
--=====================================================================
local function ScanAndHitNotes()
	local container = CONFIG.NotesContainerPath
	if not container then
		return
	end

	for _, note in ipairs(container:GetChildren()) do
		local y = GetNoteY(note)
		if y and math.abs(y - 0) <= CONFIG.HitWindowY then
			local lane = GetLaneFromNote(note)
			if lane then
				HitNote(note, lane)
			end
		end
	end
end

if CONFIG.PollInterval > 0 then
	while true do
		ScanAndHitNotes()
		task.wait(CONFIG.PollInterval)
	end
else
	RunService.RenderStepped:Connect(ScanAndHitNotes)
end
