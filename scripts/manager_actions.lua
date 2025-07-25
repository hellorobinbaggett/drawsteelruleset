--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

--  ACTION FLOW
--
--	1. INITIATE ACTION (DRAG OR DOUBLE-CLICK)
--	2. DETERMINE TARGETS (DROP OR TARGETING SUBSYSTEM)
--	3. APPLY MODIFIERS
--	4. PERFORM ROLLS (IF ANY)
--	5. RESOLVE ACTION

-- 	NOTE: Rolls with sTargeting = "all" which use effect modifiers need to
-- 		handle effect application on resolution by checking target order field;
--		since there will be no target specified in mod handler,
--		but will be specified in the result handler.
--		i.e. "if rSource and rTarget and rTarget.nOrder then"

-- 	ROLL
--		.sType
--		.sDesc
--		.aDice
--		.nMod
--		(Any other fields added as string -> string map, if possible)

-- 	FLOW
--
--	(DIRECT)
--		PerformAction -> performMultiAction ->
--		actionDirect -> actionRoll -> ...
--	(DRAG)
--		PerformAction -> performMultiAction ->
--		encodeActionForDrag -> (drag/drop) ->
--		decodeActionFromDrag -> actionRoll -> ...
--	(ALL)
--		actionRoll -> applyModifiersAndRoll ->
--		roll -> (dice roll) -> onDiceLanded ->
--		decodeActionFromDrag -> handleResolution

function onTabletopInit()
	Interface.addKeyedEventHandler("onHotkeyActivated", "", ActionsManager.actionHotkey);
end

--
-- HANDLERS
--

function initAction(sActionType)
	if not GameSystem.actions[sActionType] and ((sActionType or "") ~= "") then
		GameSystem.actions[sActionType] = { bUseModStack = "true" };
	end
end

local aTargetingHandlers = {};
function registerTargetingHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aTargetingHandlers[sActionType] = callback;
end
function unregisterTargetingHandler(sActionType)
	if aTargetingHandlers then
		aTargetingHandlers[sActionType] = nil;
	end
end

local aModHandlers = {};
function registerModHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aModHandlers[sActionType] = callback;
end
function unregisterModHandler(sActionType)
	if aModHandlers then
		aModHandlers[sActionType] = nil;
	end
end

local aPostRollHandlers = {};
function registerPostRollHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aPostRollHandlers[sActionType] = callback;
end
function unregisterPostRollHandler(sActionType)
	if aPostRollHandlers then
		aPostRollHandlers[sActionType] = nil;
	end
end

local aResultHandlers = {};
function registerResultHandler(sActionType, callback)
	ActionsManager.initAction(sActionType);
	aResultHandlers[sActionType] = callback;
end
function unregisterResultHandler(sActionType)
	if aResultHandlers then
		aResultHandlers[sActionType] = nil;
	end
end

--
-- HELPER FUNCTIONS
--

function doesRollHaveDice(rRoll)
	if rRoll and rRoll.aDice then
		if #(rRoll.aDice) > 0 then
			return true;
		end
		if (rRoll.aDice.expr or "") ~= "" then
			return true;
		end
	end
	return false;
end

--
--  ACTIONS
--

function performAction(draginfo, rActor, rRoll)
	if not rRoll then
		return;
	end

	if Session.IsHost and CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
		rRoll.bSecret = true;
	end

	ActionsManager.performMultiAction(draginfo, rActor, rRoll.sType, { rRoll });
end

function performMultiAction(draginfo, rActor, sType, rRolls)
	if not rRolls or #rRolls < 1 then
		return false;
	end

	if draginfo then
		ActionsManager.encodeActionForDrag(draginfo, rActor, sType, rRolls);
	else
		ActionsManager.actionDirect(rActor, sType, rRolls);
	end
	return true;
end

function actionHotkey(draginfo)
	local sDragType = draginfo.getType();
	if not GameSystem.actions[sDragType] then
		return;
	end

	local rSource, rRolls = ActionsManager.decodeActionFromDrag(draginfo, false);
	ActionsManager.actionDirect(rSource, sDragType, rRolls);
	return true;
end

function actionDrop(draginfo, rTarget)
	local sDragType = draginfo.getType();
	if not GameSystem.actions[sDragType] then
		return false;
	end

	local rSource, rRolls = ActionsManager.decodeActionFromDrag(draginfo, false);

	-- NOTE: tTargetGroups parameter assumes a list of targeting groups
	local tTargetGroups;
	if rTarget or ModifierStack.getTargeting() then
		tTargetGroups = ActionsManager.getTargeting(rSource, rTarget, sDragType, rRolls);
	else
		tTargetGroups = { { } };
	end

	ActionsManager.actionRoll(rSource, tTargetGroups, rRolls);

	return true;
end

function actionDropHelper(draginfo, bResolveIfNoDice)
	local rSource, aTargets = ActionsManager.decodeActors(draginfo);

	local bModStackUsed = false;
	ActionsManager.lockModifiers();

	draginfo.setSlot(1);
	for i = 1, draginfo.getSlotCount() do
		if ActionsManager.applyModifiersToDragSlot(draginfo, i, rSource, bResolveIfNoDice) then
			bModStackUsed = true;
		end
	end

	ActionsManager.unlockModifiers(bModStackUsed);

	return rSource, aTargets;
end

-- NOTE: tTargetGroups parameter assumes a list of targeting groups
function actionDirect(rActor, sDragType, rRolls, tTargetGroups)
	if not tTargetGroups then
		if ModifierStack.getTargeting() then
			tTargetGroups = ActionsManager.getTargeting(rActor, nil, sDragType, rRolls);
		else
			tTargetGroups = { { } };
		end
	end

	ActionsManager.actionRoll(rActor, tTargetGroups, rRolls);
end

-- NOTE: tTargetGroups return value assumes a list of targeting groups returned
function getTargeting(rSource, rTarget, sDragType, rRolls)
	local tTargetGroups = {};

	if rTarget then
		table.insert(tTargetGroups, { rTarget });
	elseif GameSystem.actions[sDragType] and GameSystem.actions[sDragType].sTargeting then
		if (#rRolls == 1) and rRolls[1].bSelfTarget then
			tTargetGroups = { { rSource } };
		elseif GameSystem.actions[sDragType].sTargeting == "all" then
			tTargetGroups = { TargetingManager.getFullTargets(rSource) };
		elseif GameSystem.actions[sDragType].sTargeting == "each" then
			local aTempTargets = TargetingManager.getFullTargets(rSource);
			if #aTempTargets <= 1 then
				tTargetGroups = { aTempTargets };
			else
				tTargetGroups = {};
				for _,vTarget in ipairs(aTempTargets) do
					table.insert(tTargetGroups, { vTarget });
				end
			end
		end
	end

	local fTarget = aTargetingHandlers[sDragType];
	if fTarget then
		tTargetGroups = fTarget(rSource, tTargetGroups, rRolls);
	end
	if not tTargetGroups then
		tTargetGroups = {};
	end
	if #tTargetGroups == 0 then
		table.insert(tTargetGroups, {});
	end

	return tTargetGroups;
end

function encodeActors(draginfo, rSource, aTargets)
	local sSourceNode = nil;
	if rSource then
		sSourceNode = ActorManager.getCreatureNodeName(rSource);
	end
	if sSourceNode then
		draginfo.addShortcut(ActorManager.getRecordType(rSource), sSourceNode);
		ActionsManager.encodeActorActiveEffectNodes(draginfo, rSource, 1);
	else
		draginfo.addShortcut();
	end

	if aTargets then
		for kTarget,vTarget in ipairs(aTargets) do
			local sTargetNode = ActorManager.getCreatureNodeName(vTarget);
			if sTargetNode then
				draginfo.addShortcut(ActorManager.getRecordType(vTarget), sTargetNode);
				ActionsManager.encodeActorActiveEffectNodes(draginfo, vTarget, kTarget + 1);
			end
		end
	end
end
function encodeActorActiveEffectNodes(draginfo, rActor, nActorIndex)
	local tActive = ActorManager.getActiveEffectNodes(rActor);
	local sMetaKey = "__actor" .. nActorIndex .. "_active";
	for kActive,vActive in ipairs(tActive) do
		if type(vActive) == "databasenode" then
			draginfo.setMetaData(sMetaKey .. kActive, DB.getPath(vActive));
		else
			draginfo.setMetaData(sMetaKey .. kActive, tostring(vActive) or "");
		end
	end
end

function decodeActors(draginfo)
	local rSource = nil;
	local aTargets = {};

	for k,v in ipairs(draginfo.getShortcutList()) do
		local rActor = ActorManager.resolveActor(v.recordname);
		ActionsManager.decodeActorActiveEffectNodes(draginfo, rActor, k);
		if k == 1 then
			rSource = rActor;
		else
			if rActor then
				table.insert(aTargets, rActor);
			end
		end
	end

	return rSource, aTargets;
end
function decodeActorActiveEffectNodes(draginfo, rActor, nActorIndex)
	if not rActor then
		return;
	end

	local sMetaKey = "__actor" .. nActorIndex .. "_active";
	local tMetaData = draginfo.getMetaDataList();
	local kActive = 1;
	while tMetaData[sMetaKey .. kActive] do
		ActorManager.addActiveEffectNode(rActor, tMetaData[sMetaKey .. kActive]);
		kActive = kActive + 1;
	end
end

function encodeActionForDrag(draginfo, rSource, sType, rRolls)
	ActionsManager.encodeActors(draginfo, rSource);

	draginfo.setType(sType);

	if GameSystem.actions[sType] and GameSystem.actions[sType].sIcon then
		draginfo.setIcon(GameSystem.actions[sType].sIcon);
	elseif sType ~= "dice" then
		draginfo.setIcon("action_roll");
	end
	if #rRolls == 1 then
		draginfo.setDescription(rRolls[1].sDesc);
	end

	for kRoll, rRoll in ipairs(rRolls) do
		ActionsManager.encodeRollForDrag(draginfo, kRoll, rRoll);
	end

	local bSecret = (#rRolls > 0 and rRolls[1].bSecret);
	draginfo.setSecret(bSecret);
end
function encodeRollForDrag(draginfo, i, rRoll)
	DiceManager.onPreEncodeRoll(rRoll);

	draginfo.setSlot(i);
	ActionsManager.helperEncodeRollToDrag(draginfo, rRoll);
end
function helperEncodeRollToDrag(draginfo, rRoll, nOrigDice)
	for k,v in pairs(rRoll) do
		if k == "sType" then
			draginfo.setSlotType(v);
		elseif k == "sDesc" then
			draginfo.setStringData(v);
		elseif k == "aDice" then
			if nOrigDice then
				local nNewDice = #(rRoll.aDice or {});
				for i = nOrigDice + 1, nNewDice do
					local vDie = rRoll.aDice[i];
					if type(vDie) == "table" then
						draginfo.addDie(vDie.type);
					else
						draginfo.addDie(vDie);
					end
				end
			else
				draginfo.setDiceData(v);
			end
		elseif k == "nMod" then
			draginfo.setNumberData(v);
		elseif type(k) ~= "table" then
			local sk = tostring(k) or "";
			if sk ~= "" then
				if type(v) == "boolean" then
					draginfo.setMetaData(sk, v and 1 or 0);
				else
					draginfo.setMetaData(sk, tostring(v) or "");
				end
			end
		end
	end
end

function decodeActionFromDrag(draginfo, bFinal)
	local rSource, aTargets = ActionsManager.decodeActors(draginfo);

	local rRolls = {};
	for i = 1, draginfo.getSlotCount() do
		table.insert(rRolls, ActionsManager.decodeRollFromDrag(draginfo, i, bFinal));
	end

	return rSource, rRolls, aTargets;
end
function decodeRollFromDrag(draginfo, i, bFinal)
	draginfo.setSlot(i);
	local rRoll = ActionsManager.helperDecodeRollFromDrag(draginfo, bFinal);

	DiceManager.onPostDecodeRoll(rRoll, bFinal);

	return rRoll;
end
function helperDecodeRollFromDrag(draginfo, bFinal)
	local rRoll = {};
	for k,v in pairs(draginfo.getMetaDataList()) do
		if k:match("^n[A-Z]") then
			rRoll[k] = tonumber(v) or nil;
		elseif k:match("^b[A-Z]") then
			rRoll[k] = ((tonumber(v) or 0) == 1);
		else
			rRoll[k] = v;
		end
	end

	rRoll.sType = draginfo.getSlotType();
	if rRoll.sType == "" then
		rRoll.sType = draginfo.getType();
	end

	rRoll.sDesc = draginfo.getStringData();
	if bFinal and (rRoll.sDesc or "") == "" then
		rRoll.sDesc = draginfo.getDescription();
	end
	rRoll.nMod = draginfo.getNumberData();

	rRoll.aDice = draginfo.getDiceData() or {};
	rRoll.nTotal = rRoll.aDice.total;

	rRoll.bSecret = draginfo.getSecret();

	return rRoll;
end

--
--  APPLY MODIFIERS
--

-- NOTE: tTargetGroups parameter for this function assumes a list of targeting groups
function actionRoll(rSource, tTargetGroups, rRolls)
	local bModStackUsed = false;
	ActionsManager.lockModifiers();

	for _,tTargets in ipairs(tTargetGroups) do
		for _,vRoll in ipairs(rRolls) do
			if ActionsManager.applyModifiersAndRoll(rSource, tTargets, true, vRoll) then
				bModStackUsed = true;
			end
		end
	end

	ActionsManager.unlockModifiers(bModStackUsed);
end

function applyModifiersAndRoll(rSource, vTarget, bMultiTarget, rRoll)
	local rNewRoll = UtilityManager.copyDeep(rRoll);
	local bModStackUsed;

	if bMultiTarget then
		if vTarget and #vTarget == 1 then
			bModStackUsed = ActionsManager.applyModifiers(rSource, vTarget[1], rNewRoll);
		else
			-- Only apply non-target specific modifiers before roll
			bModStackUsed = ActionsManager.applyModifiers(rSource, nil, rNewRoll);
		end
	else
		bModStackUsed = ActionsManager.applyModifiers(rSource, vTarget, rNewRoll);
	end

	ActionsManager.roll(rSource, vTarget, rNewRoll, bMultiTarget);

	return bModStackUsed;
end

function applyModifiersToDragSlot(draginfo, i, rSource, bResolveIfNoDice)
	local rRoll = ActionsManager.decodeRollFromDrag(draginfo, i);

	local bHasDice = ActionsManager.doesRollHaveDice(rRoll);
	local nDice = #(rRoll.aDice or {});
	local bModStackUsed = ActionsManager.applyModifiers(rSource, nil, rRoll);

	if bResolveIfNoDice and not bHasDice then
		ActionsManager.resolveAction(rSource, nil, rRoll);
	else
		ActionsManager.helperEncodeRollToDrag(draginfo, rRoll, nDice);
	end

	return bModStackUsed;
end

function lockModifiers()
	ModifierStack.lock();
	EffectManager.lock();
end
function unlockModifiers(bReset)
	ModifierStack.unlock(bReset);
	EffectManager.unlock();
end

function applyModifiers(rSource, rTarget, rRoll, bSkipModStack)
	local bAddModStack = ActionsManager.doesRollHaveDice(rRoll);
	if bSkipModStack then
		bAddModStack = false;
	elseif GameSystem.actions[rRoll.sType] then
		bAddModStack = GameSystem.actions[rRoll.sType].bUseModStack;
	end

	local fMod = aModHandlers[rRoll.sType];
	if fMod then
		local bReturn = fMod(rSource, rTarget, rRoll);
		if bReturn ~= true then
			rRoll.aDice.expr = nil;
		end
	end

	if bAddModStack then
		local bDescNotEmpty = ((rRoll.sDesc or "") ~= "");
		local sStackDesc, nStackMod = ModifierStack.getStack(bDescNotEmpty);

		if sStackDesc ~= "" then
			if bDescNotEmpty then
				rRoll.sDesc = rRoll.sDesc .. " [" .. sStackDesc .. "]";
			else
				rRoll.sDesc = sStackDesc;
			end
		end
		rRoll.nMod = rRoll.nMod + nStackMod;
	end

	return bAddModStack;
end

--
--	RESOLVE DICE
--

function buildThrow(rSource, vTargets, rRoll, bMultiTarget)
	local rThrow = {};

	rThrow.type = rRoll.sType;
	rThrow.description = rRoll.sDesc;
	rThrow.secret = rRoll.bSecret;

	rThrow.shortcuts = {};
	if rSource then
		local sSourceActorPath = ActorManager.getCreatureNodeName(rSource);
		table.insert(rThrow.shortcuts, { recordname = sSourceActorPath });
	else
		table.insert(rThrow.shortcuts, {});
	end
	if vTargets then
		if bMultiTarget then
			for _,v in ipairs(vTargets) do
				local sTargetActorPath = ActorManager.getCreatureNodeName(v);
				table.insert(rThrow.shortcuts, { recordname = sTargetActorPath });
			end
		else
			local sTargetActorPath = ActorManager.getCreatureNodeName(vTargets);
			table.insert(rThrow.shortcuts, { recordname = sTargetActorPath });
		end
	end

	local tMeta = {};
	for k,v in pairs(rRoll) do
		if type(k) ~= "table" then
			local sk = tostring(k) or "";
			if sk ~= "" then
				local sTypeVar = type(v);
				if sTypeVar == "boolean" then
					tMeta[sk] = tostring(v and 1 or 0);
				elseif (sTypeVar == "string") or (sTypeVar == "number") then
					tMeta[sk] = v;
				end
			end
		end
	end

	local rSlot = {};
	rSlot.number = rRoll.nMod;
	rSlot.dice = rRoll.aDice;
	rSlot.metadata = tMeta;

	rThrow.slots = { rSlot };

	return rThrow;
end

function roll(rSource, vTargets, rRoll, bMultiTarget)
	if ActionsManager.doesRollHaveDice(rRoll) then
		DiceManager.onPreEncodeRoll(rRoll);

		if not rRoll.bTower and OptionsManager.isOption("MANUALROLL", "on") then
			if bMultiTarget then
				ManualRollManager.addRoll(rRoll, rSource, vTargets);
			else
				ManualRollManager.addRoll(rRoll, rSource, { vTargets });
			end
		else
			local rThrow = ActionsManager.buildThrow(rSource, vTargets, rRoll, bMultiTarget);
			Comm.throwDice(rThrow);
		end
	else
		if bMultiTarget then
			ActionsManager.handleResolution(rRoll, rSource, vTargets);
		else
			ActionsManager.handleResolution(rRoll, rSource, { vTargets });
		end
	end
end

function onDiceLanded(draginfo)
	local sDragType = draginfo.getType();
	if GameSystem.actions[sDragType] then
		local rSource, rRolls, aTargets = ActionsManager.decodeActionFromDrag(draginfo, true);

		for _,vRoll in ipairs(rRolls) do
			if ActionsManager.doesRollHaveDice(vRoll) then
				ActionsManager.handleResolution(vRoll, rSource, aTargets);
			end
		end

		return true;
	end
end

function handleResolution(vRoll, rSource, aTargets)
	if vRoll.sReplaceDieResult then
		local aReplaceDieResult = StringManager.split(vRoll.sReplaceDieResult, "|");
		for kDie,vDie in ipairs(vRoll.aDice) do
			if aReplaceDieResult[kDie] then
				vDie.result = tonumber(aReplaceDieResult[kDie]) or 0;
				vDie.value = vDie.result;
			end
		end
	end

	local fPostRoll = aPostRollHandlers[vRoll.sType];
	if fPostRoll then
		fPostRoll(rSource, vRoll);
	end

	if not aTargets or (#aTargets == 0) then
		ActionsManager.resolveAction(rSource, nil, vRoll);
	elseif #aTargets == 1 then
		ActionsManager.resolveAction(rSource, aTargets[1], vRoll);
	else
		for kTarget,rTarget in ipairs(aTargets) do
			local rRollTarget = UtilityManager.copyDeep(vRoll);
			rTarget.nOrder = kTarget;
			ActionsManager.resolveAction(rSource, rTarget, rRollTarget);
		end
	end
end

function onChatDragStart(draginfo)
	local sDragType = draginfo.getType();
	if GameSystem.actions[sDragType] and GameSystem.actions[sDragType].sIcon then
		draginfo.setIcon(GameSystem.actions[sDragType].sIcon);
	end
end

--
--  RESOLVE ACTION
--  (I.E. DISPLAY CHAT MESSAGE, COMPARISONS, ETC.)
--

function resolveAction(rSource, rTarget, rRoll)
	local fResult = aResultHandlers[rRoll.sType];
	if fResult then
		fResult(rSource, rTarget, rRoll);
	else
		local rMessage = ActionsManager_DS.createActionMessage(rSource, rRoll);
		Comm.deliverChatMessage(rMessage);
	end
end

function createActionMessage(rSource, rRoll)
	-- Build the basic message to deliver
	local rMessage = ChatManager.createBaseMessage(rSource, rRoll.sUser);
	rMessage.type = rRoll.sType;
	rMessage.text = rRoll.sDesc;
	rMessage.dice = rRoll.aDice;
	rMessage.diemodifier = rRoll.nMod;
	rMessage.diceskipexpr = rRoll.diceskipexpr;

	-- Check to see if this roll should be secret (GM or dice tower tag)
	if rRoll.bSecret then
		rMessage.secret = true;
		if rRoll.bTower then
			rMessage.assets = rMessage.assets or {};
			table.insert(rMessage.assets, ChatIdentityManager.getDiceTowerAsset());
		end
	elseif Session.IsHost and OptionsManager.isOption("REVL", "off") then
		rMessage.secret = true;
	end

	return rMessage;
end

function total(rRoll)
	if Utility.getDiceTotal then
		return Utility.getDiceTotal(rRoll.aDice) + rRoll.nMod;
	end

	local nTotal = 0;
	for _,v in ipairs(rRoll.aDice) do
		if not v.dropped then
			if v.value then
				nTotal = nTotal + v.value;
			else
				nTotal = nTotal + v.result;
			end
		end
	end
	nTotal = nTotal + rRoll.nMod;

	return nTotal;
end

function outputResult(bTower, rSource, rTarget, rMessageGM, rMessagePlayer)
	if bTower then
		rMessageGM.secret = true;
		Comm.deliverChatMessage(rMessageGM, "");
	else
		ActionsManager.messageResult(false, rSource, rTarget, rMessageGM, rMessagePlayer);
	end
end

function messageResult(_, rSource, rTarget, rMessageGM, rMessagePlayer)
	local bInvolvesFriendlyUnits =
		(not rSource or ActorManager.isFaction(rSource, "friend")) and
		(not rTarget or ActorManager.isFaction(rTarget, "friend"));
	local bShowResultsToPlayer;
	local sOptSHRR = OptionsManager.getOption("SHRR");
	if sOptSHRR == "off" then
		bShowResultsToPlayer = false;
	elseif sOptSHRR == "pc" then
		bShowResultsToPlayer = bInvolvesFriendlyUnits;
	else
		bShowResultsToPlayer = true;
	end

	if bShowResultsToPlayer then
		local nodeCT = ActorManager.getCTNode(rTarget);
		if nodeCT and CombatManager.isCTHidden(nodeCT) then
			rMessageGM.secret = true;
			Comm.deliverChatMessage(rMessageGM, "");
		else
			rMessageGM.secret = false;
			Comm.deliverChatMessage(rMessageGM);
		end
	else
		rMessageGM.secret = true;
		Comm.deliverChatMessage(rMessageGM, "");

		if bInvolvesFriendlyUnits then
			if Session.IsHost then
				local tUsers = User.getActiveUsers();
				if #tUsers > 0 then
					Comm.deliverChatMessage(rMessagePlayer, tUsers);
				end
			else
				Comm.addChatMessage(rMessagePlayer);
			end
		end
	end
end
