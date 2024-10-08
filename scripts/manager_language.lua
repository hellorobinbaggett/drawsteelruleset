--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

OOB_MSGTYPE_LANGCHAT = "languagechat";
OOB_MSGTYPE_LANGCHAT_RESULT = "languagechatresult";

CAMPAIGN_LANGUAGE_LIST = "languages";
CAMPAIGN_LANGUAGE_LIST_NAME = "name";
CAMPAIGN_LANGUAGE_FONT_NAME = "font";

CHAR_LANGUAGE_LIST = "languagelist";
CHAR_LANGUAGE_LIST_NAME = "name";

local sActiveIdentity = "";
local bCampaignHandlers = false;

function onInit()
	LanguageManager.initSpecialCases();
end
function onTabletopInit()
	if Session.IsHost then
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_LANGCHAT, LanguageManager.handleLangChat);
	end
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_LANGCHAT_RESULT, LanguageManager.handleLangChatResult);

	ChatManager.registerDropCallback("language", LanguageManager.onChatDrop);
	ChatManager.registerDeliverMessageCallback(LanguageManager.onChatDeliverMessage);

	if not Session.IsHost then
		User.addEventHandler("onIdentityActivation", LanguageManager.onIdentityActivation);
		User.addEventHandler("onIdentityStateChange", LanguageManager.onIdentityStateChange);
	end

	if Session.IsHost then
		DB.setPublic(DB.createNode(CAMPAIGN_LANGUAGE_LIST), true);
		if DB.getChildCount(CAMPAIGN_LANGUAGE_LIST) == 0 then
			LanguageManager.populateCampaignLanguages();
		end
		
		LanguageManager.addCampaignLanguageHandlers();
		LanguageManager.refreshCampaignLanguages();
	end
end

--
--	LANGUAGE DATA HANDLING
--

aCampaignLang = {};
aCampaignLangLower = {};

function isCampaignLanguage(s)
	if not s then
		return false;
	end
	return (LanguageManager.aCampaignLangLower[s:lower()] ~= nil);
end
function getCampaignLanguageMap()
	return LanguageManager.aCampaignLang;
end
function getCampaignLanguageMapLower()
	return LanguageManager.aCampaignLangLower;
end
function getCampaignLanguageFont(s)
	if not s then
		return false;
	end
	return LanguageManager.aCampaignLangLower[s:lower()] or "";
end

aLanguageSpeaksAll = {};
aLanguagesUnderstandsAll = {};
aLanguagesTongues = {};

function initSpecialCases()
	LanguageManager.aLanguageSpeaksAll[Interface.getString("lang_val_speaksall"):lower()] = true;
	LanguageManager.aLanguagesUnderstandsAll[Interface.getString("lang_val_understandsall"):lower()] = true;
	LanguageManager.aLanguagesUnderstandsAll[Interface.getString("lang_val_comprehendlanguages"):lower()] = true;
	LanguageManager.aLanguagesTongues[Interface.getString("lang_val_tongues"):lower()] = true;
end
function isCampaignSpeaksAllTag(s)
	if not s then
		return false;
	end
	return (LanguageManager.aLanguageSpeaksAll[s:lower()] ~= nil);
end
function isCampaignUnderstandsAllTag(s)
	if not s then
		return false;
	end
	return (LanguageManager.aLanguagesUnderstandsAll[s:lower()] ~= nil);
end
function isCampaignTonguesTag(s)
	if not s then
		return false;
	end
	return (LanguageManager.aLanguagesTongues[s:lower()] ~= nil);
end

function populateCampaignLanguages()
	if not GameSystem.languages then
		return;
	end

	for kLang,vLang in pairs(GameSystem.languages) do
		local nodeLang = DB.createChild(CAMPAIGN_LANGUAGE_LIST);
		DB.setValue(nodeLang, "name", "string", kLang);
		DB.setValue(nodeLang, "font", "string", vLang);
	end
end
function addCampaignLanguageHandlers()
	bCampaignHandlers = true;
	DB.addHandler(CAMPAIGN_LANGUAGE_LIST, "onChildDeleted", LanguageManager.refreshCampaignLanguages);
	DB.addHandler(CAMPAIGN_LANGUAGE_LIST .. ".*." .. CAMPAIGN_LANGUAGE_LIST_NAME, "onUpdate", LanguageManager.refreshCampaignLanguages);
	DB.addHandler(CAMPAIGN_LANGUAGE_LIST .. ".*." .. CAMPAIGN_LANGUAGE_FONT_NAME, "onUpdate", LanguageManager.refreshCampaignLanguages);
end
function refreshCampaignLanguages()
	-- Rebuild the campaign language dictionary for fast lookup
	LanguageManager.aCampaignLang = {};
	LanguageManager.aCampaignLangLower = {};
	for _,v in ipairs(DB.getChildList(CAMPAIGN_LANGUAGE_LIST)) do
		local sLang = DB.getValue(v, CAMPAIGN_LANGUAGE_LIST_NAME, "")
		sLang = StringManager.trim(sLang)
		if (sLang or "") ~= "" then
			local sFont = DB.getValue(v, CAMPAIGN_LANGUAGE_FONT_NAME, "");
			sFont = StringManager.trim(sFont);
			
			LanguageManager.aCampaignLang[sLang] = sFont;
			LanguageManager.aCampaignLangLower[sLang:lower()] = sFont;
		end
	end
	
	-- Refresh the chat window, since the campaign languages have changed
	LanguageManager.refreshChatLanguages();
end

--
--	CHARACTER ACTIVATION HANDLING
--

function onIdentityActivation(sIdentity, sUser, bActive)
	if Session.UserName == sUser and not bActive then
		if sActiveIdentity == sIdentity then
			LanguageManager.setSpeakerIdentity("");
		end
	end
end
function onIdentityStateChange(sIdentity, sUser, sState, bState)
	if Session.UserName == sUser and sState == 'current' and bState then
		LanguageManager.setSpeakerIdentity(sIdentity);
	end
end
function setSpeakerIdentity(sIdentity)
	if not bCampaignHandlers then
		LanguageManager.refreshCampaignLanguages();
	end
	
	if (sActiveIdentity or "") == (sIdentity or "") then
		return;
	end
	
	if (sActiveIdentity or "") ~= "" then
		DB.removeHandler(DB.getPath("charsheet", sActiveIdentity, CHAR_LANGUAGE_LIST), "onChildDeleted", LanguageManager.refreshChatLanguages);
		DB.removeHandler(DB.getPath("charsheet", sActiveIdentity, CHAR_LANGUAGE_LIST, "*", CHAR_LANGUAGE_LIST_NAME), "onUpdate", LanguageManager.refreshChatLanguages);
	end
	
	if (sIdentity or "") ~= "" then
		DB.addHandler(DB.getPath("charsheet", sActiveIdentity, CHAR_LANGUAGE_LIST), "onChildDeleted", LanguageManager.refreshChatLanguages);
		DB.addHandler(DB.getPath("charsheet", sActiveIdentity, CHAR_LANGUAGE_LIST, "*", CHAR_LANGUAGE_LIST_NAME), "onUpdate", LanguageManager.refreshChatLanguages);
	end
	
	sActiveIdentity = sIdentity or "";
	
	LanguageManager.refreshChatLanguages();
end

--
--	CHAT WINDOW BEHAVIORS
--

function onChatDrop(draginfo)
	LanguageManager.setCurrentLanguage(draginfo.getStringData());
	return true;
end
function onChatDeliverMessage(msg, sMode)
	if sMode ~= "chat" then
		return false;
	end
	local w = ChatManager.getChatWindow();
	if not w or not w.language then
		return false;
	end
	local sLang = w.language.getValue();
	if (sLang or "") == "" then
		return false;
	end

	msg.type = LanguageManager.OOB_MSGTYPE_LANGCHAT;
	msg.mode = sMode;
	msg.language = sLang;
	Comm.deliverOOBMessage(msg, "");
	return true;
end
function handleLangChatResult(msgOOB)
	Comm.addChatMessage(msgOOB);
end

function refreshChatLanguages()
	-- If no chat window, then we don't need to refresh anything
	local w = ChatManager.getChatWindow();
	if not w then
		return;
	end
	
	-- Determine which languages are valid for the active identity/user
	local aSpokenLang = LanguageManager.getKnownLanguages(sActiveIdentity, Session.IsHost);
	local aSorted = {};
	for kLang,_ in pairs(aSpokenLang) do
		table.insert(aSorted, kLang);
	end
	table.sort(aSorted);
	
	-- If the current chat window language selection is not in the list, then clear the chat window language field
	local sChatWindowLanguage = w.language.getValue();
	if not StringManager.contains(aSorted, sChatWindowLanguage) then
		w.language.setValue("");
	end
	
	-- Set the current language value options in the drop down control
	w.language.clear();
	w.language.add("");
	w.language.addItems(aSorted);
end
function setCurrentLanguage(sLang)
	if (sLang or "") == "" then
		return;
	end
	
	-- If no chat window, then we don't need to refresh anything
	local w = ChatManager.getChatWindow();
	if not w then
		return;
	end

	-- Make sure the language activated is in the list
	if w.language.hasValue(sLang) then
		if w.language.getValue() ~= sLang then
			w.language.setValue(sLang);
		end
	else
		ChatManager.SystemMessage(Interface.getString("message_chatsetlang_unavailable"));
	end
end

function getKnownLanguages(sIdentity, bHost)
	local aSpokenLang = {};
	local aUnderstoodLang = {};
	local bSpeaksAll = false;
	local bUnderstandsAll = false;
	
	if bHost then
		bSpeaksAll = true;
		bUnderstandsAll = true;
	else
		local nodeChar = DB.findNode("charsheet." .. sIdentity);
		if nodeChar then
			for _,v in ipairs(DB.getChildList(nodeChar, CHAR_LANGUAGE_LIST)) do
				local sLang = DB.getValue(v, CHAR_LANGUAGE_LIST_NAME, "");
				sLang = StringManager.trim(sLang);
				if (sLang or "") ~= "" then
					if LanguageManager.isCampaignTonguesTag(sLang) then
						bSpeaksAll = true;
						bUnderstandsAll = true;
					elseif LanguageManager.isCampaignSpeaksAllTag(sLang) then
						bSpeaksAll = true;
					elseif LanguageManager.isCampaignUnderstandsAllTag(sLang) then
						bUnderstandsAll = true;
					elseif LanguageManager.isCampaignLanguage(sLang) then
						aSpokenLang[sLang] = 100;
						aUnderstoodLang[sLang] = 100;
					end
				end
			end
		end
	end
	
	if bSpeaksAll then
		aSpokenLang = {}
		for kLang,_ in pairs(LanguageManager.getCampaignLanguageMap()) do
			aSpokenLang[kLang] = 100;
		end
	end
	if bUnderstandsAll then
		aUnderstoodLang = {}
		for kLang,_ in pairs(LanguageManager.getCampaignLanguageMap()) do
			aUnderstoodLang[kLang] = 100;
		end
	end
	
	return aSpokenLang, aUnderstoodLang
end

function handleLangChat(msgOOB)
	-- Validation
	local sLang = msgOOB.language
	if (sLang or "") == "" then
		return;
	end
	if not LanguageManager.isCampaignLanguage(sLang) then
		local sError = string.format(Interface.getString("error_chathandlelang_unavailable"), sLang, msgOOB.text);
		ChatManager.SystemMessage(sError);
		return;
	end
	
	-- Deliver customized message to each player
	local aGMUnderstood = {};
	for _,vUser in ipairs(User.getActiveUsers()) do
		local aPlayerUnderstood = {};
		local bLanguageMiss;
		local aUserPCKnownLanguage = {};
		local aUserPCUnknownLanguage = {};
		for _,vIdentity in ipairs(User.getActiveIdentities(vUser)) do
			local sCharName = DB.getValue("charsheet." .. vIdentity .. ".name", "");
			local _,aUnderstoodLang = LanguageManager.getKnownLanguages(vIdentity);
			if aUnderstoodLang[sLang] and aUnderstoodLang[sLang] > 0 then
				if aUnderstoodLang[sLang] >= 100 then
					table.insert(aGMUnderstood, { sName = sCharName, nPercent = 100 });
					table.insert(aPlayerUnderstood, { sName = sCharName, nPercent = 100 });
				else
					table.insert(aGMUnderstood, { sName = sCharName, nPercent = aUnderstoodLang[sLang] });
					table.insert(aPlayerUnderstood, { sName = sCharName, nPercent = aUnderstoodLang[sLang] });
				end
			else
				table.insert(aGMUnderstood, { sName = sCharName, nPercent = 0 });
				table.insert(aPlayerUnderstood, { sName = sCharName, nPercent = 0 });
			end
		end
		
		LanguageManager.deliverLanguageMessagesToUser(vUser, msgOOB, sLang, aPlayerUnderstood);
	end
	
	-- Deliver translated message to GM
	LanguageManager.deliverLanguageMessagesToUser("", msgOOB, sLang, aGMUnderstood);
end

function deliverLanguageMessagesToUser(sUser, msg, sLang, aUnderstood)
	-- Make a copy of the message object, so we can change it
	local msgCopy = UtilityManager.copyDeep(msg);
	msgCopy.type = LanguageManager.OOB_MSGTYPE_LANGCHAT_RESULT;
	
	-- Determine the alternate font to use, if any
	local sFont = LanguageManager.getCampaignLanguageFont(sLang);
	
	-- Handle host messages
	local bDisplayUsers = false;
	if sUser == "" then
		if (sFont or "") ~= "" then
			msgCopy.sender = (msg.sender or "") .. " [" .. sLang .. "]";
			msgCopy.text = Interface.getString("tag_chathandlelang_translation") .. " " .. msgCopy.text;
			Comm.deliverOOBMessage(msgCopy, sUser);

			msgCopy.mode = "chat";
			msgCopy.sender = nil;
			msgCopy.icon = nil;
			msgCopy.font = sFont;
			msgCopy.text = msg.text;
			Comm.deliverOOBMessage(msgCopy, sUser);
		else
			msgCopy.mode = "chat";
			msgCopy.sender = (msgCopy.sender or "") .. " [" .. sLang .. "]";
			Comm.deliverOOBMessage(msgCopy, sUser);
		end
		
		bDisplayUsers = true;
	else
		-- See if user understands language fully
		local nUnderstoodMin = 100;
		local nUnderstoodMax = 0;
		for _,vChar in pairs(aUnderstood) do
			nUnderstoodMin = math.min(nUnderstoodMin, vChar.nPercent);
			nUnderstoodMax = math.max(nUnderstoodMax, vChar.nPercent);
		end
		
		if nUnderstoodMax >= 100 then
			if (sFont or "") ~= "" then
				msgCopy.sender = (msg.sender or "") .. " [" .. sLang .. "]";
				msgCopy.text = Interface.getString("tag_chathandlelang_translation") .. " " .. msgCopy.text;
				Comm.deliverOOBMessage(msgCopy, sUser);

				msgCopy.mode = "chat";
				msgCopy.sender = nil;
				msgCopy.icon = nil;
				msgCopy.font = sFont;
				msgCopy.text = msg.text;
				Comm.deliverOOBMessage(msgCopy, sUser);
			else
				msgCopy.mode = "chat";
				msgCopy.sender = (msgCopy.sender or "") .. " [" .. sLang .. "]";
				Comm.deliverOOBMessage(msgCopy, sUser);
			end
			
			if nUnderstoodMin < 100 then
				bDisplayUsers = true;
			end
		else
			local sGibberish = LanguageManager.convertStringToGibberish(msgCopy.text, sLang, nUnderstoodMax);
			local sSender = (msg.sender or "") .. " ";
			if nUnderstoodMax > 0 then
				sSender = sSender .. Interface.getString("tag_chathandlelang_partial");
			else
				sSender = sSender .. Interface.getString("tag_chathandlelang_unknown");
			end
			if (sFont or "") ~= "" then
				msgCopy.sender = sSender;
				if nUnderstoodMax > 0 then
					msgCopy.text = sGibberish;
				else
					msgCopy.text = "";
				end
				Comm.deliverOOBMessage(msgCopy, sUser);
				
				msgCopy.mode = "chat";
				msgCopy.sender = nil;
				msgCopy.icon = nil;
				msgCopy.font = sFont;
				msgCopy.text = sGibberish;
				Comm.deliverOOBMessage(msgCopy, sUser);
			else
				msgCopy.mode = "chat";
				msgCopy.sender = sSender;
				msgCopy.text = sGibberish;
				Comm.deliverOOBMessage(msgCopy, sUser);
			end
			
			if nUnderstoodMax > 0 then
				bDisplayUsers = true;
			end
		end
	end
	
	-- Show users who understood at least partially understood message
	if bDisplayUsers then
		local aPCKnownLanguage = {};
		for _,vChar in pairs(aUnderstood) do
			if vChar.nPercent > 0 then
				if vChar.nPercent >= 100 then
					table.insert(aPCKnownLanguage, vChar.sName);
				else
					table.insert(aPCKnownLanguage, vChar.sName .. " (" .. vChar.nPercent .. "%)");
				end
			end
		end
		local msgUnderstood = {font = "systemfont"};
		msgUnderstood.text = string.format("[%s: %s]", Interface.getString("message_chathandlelang_understood"), table.concat(aPCKnownLanguage, ", "));
		Comm.deliverChatMessage(msgUnderstood, sUser);
	end
end

--
--	UNKNOWN LANGUAGE HANDLING
--

function convertStringToGibberish(sInput, sLang, nUnderstood)
	if nUnderstood >= 100 then
		return sInput;
	end
	
	local sOutput = "";
	
	local aWords = StringManager.split(sInput, " ");

	-- Initialize random functions
	math.randomseed(os.time() - os.clock() * 1000);
	math.random();

	local aUnderstoodWords = {};
	for kWord,vWord in ipairs(aWords) do
		local vWordSansPunctuation = vWord:gsub("^[^%w]*", "");
		vWordSansPunctuation = vWordSansPunctuation:gsub("[^%w]*$", "");

		if not aUnderstoodWords[vWordSansPunctuation] then
			if nUnderstood > 0 then
				local bUnderstood = false;
				local nRandom = math.random(100);
				if nRandom <= nUnderstood then
					bUnderstood = true;
				end
				
				if bUnderstood then
					aUnderstoodWords[vWordSansPunctuation] = 1;
				else
					aUnderstoodWords[vWordSansPunctuation] = 0;
				end
			else
				aUnderstoodWords[vWordSansPunctuation] = 0;
			end
		end
	end
	
	local nAsciiCode;
	local nRandom;
	
	for kWord,vWord in ipairs(aWords) do
		local vPrePunctuation = vWord:match("^[^%w]*");
		local vPostPunctuation = vWord:match("[^%w]*$");
		
		local vWordSansPunctuation = vWord:gsub("^[^%w]*", "");
		vWordSansPunctuation = vWordSansPunctuation:gsub("[^%w]*$", "");

		if aUnderstoodWords[vWordSansPunctuation] == 1 then
			sOutput = sOutput .. " " .. vWord;
		else
			-- Set random seed based off the current word and the language name 
			-- Note: This returns the same gibberish for the same text in the same language
			LanguageManager.calcRandomSeedFromString(vWordSansPunctuation, sLang);

			-- nRandomLength will be added to the current length of the word - gives a different number of letters to original word.
			local nRandomLength = math.random(0,2);

			-- Create a string of random characters a-z, A-Z, 0-9 of the same length as the original string
			local sRandom = "";
			for nCharCount=1,(string.len(vWordSansPunctuation) + nRandomLength) do
				-- Get a random number 1 to 62 - this is the total number of possible unique characters
				nRandom = math.random(62);
				if nRandom < 27 then 
					nAsciiCode = nRandom + 64;
				elseif nRandom < 53 then 
					nAsciiCode = nRandom + 70;
				else 
					nAsciiCode = nRandom - 5;
				end
				sRandom = sRandom .. string.char(nAsciiCode);
			end	
			
			if vPrePunctuation then
				sRandom = vPrePunctuation .. sRandom;
			end
			if vPostPunctuation then
				sRandom = sRandom .. vPostPunctuation;
			end
			sOutput = sOutput .. " " .. sRandom;
		end
	end	

	-- Reset random functions, due to word randomizer usage
	math.randomseed(os.time() - os.clock() * 1000);
	math.random();
	
	return sOutput;
end

function calcRandomSeedFromString(sText, sLang)
	-- Calculate random seed based off text and language
	local nSeed = 0;
	local sLangAndText = (sLang or "") .. (sText or "");
	for i = 1,#sLangAndText do
		nSeed = nSeed + sLangAndText:byte(i);
	end
	
	-- Set the random seed
	math.randomseed(nSeed);
	
	-- Pull the first random number to prevent corner cases
	math.random(10);
end
