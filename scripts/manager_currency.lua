--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

-- TODO - Deprecate "coinother" ("currency" in SavageWorlds)
-- TODO - Migrate "cashonhand" to currency list or items (CHAFGCOCCOC7ERS, DGA070, MGP3800TRVMG1E, MGP40000TRVMG2E)

CAMPAIGN_CURRENCY_LIST = "currencies";
CAMPAIGN_CURRENCY_LIST_NAME = "name";
CAMPAIGN_CURRENCY_LIST_WEIGHT = "weight";
CAMPAIGN_CURRENCY_LIST_VALUE = "value";

local _bCampaignCurrenciesInit = false;
local _tCampaignCurrencies = {};

function onTabletopInit()
	if Session.IsHost then
		DB.setPublic(DB.createNode(CurrencyManager.CAMPAIGN_CURRENCY_LIST), true);
		if DB.getChildCount(CurrencyManager.CAMPAIGN_CURRENCY_LIST) == 0 then
			CurrencyManager.populateCampaignCurrencies();
		end

		CurrencyManager.addCampaignCurrencyHandlers();
		CurrencyManager.refreshCampaignCurrencies();

		CurrencyManager.setDefaultCurrency(GameSystem.currencyDefault);
	end
end

function populateCampaignCurrencies()
	if not GameSystem.currencies then
		return;
	end

	for _,vCurrency in ipairs(GameSystem.currencies) do
		local nodeCurrency = DB.createChild(CurrencyManager.CAMPAIGN_CURRENCY_LIST);
		DB.setValue(nodeCurrency, CurrencyManager.CAMPAIGN_CURRENCY_LIST_NAME, "string", vCurrency["name"] or vCurrency);
		DB.setValue(nodeCurrency, CurrencyManager.CAMPAIGN_CURRENCY_LIST_WEIGHT, "number", vCurrency["weight"] or 0);
		DB.setValue(nodeCurrency, CurrencyManager.CAMPAIGN_CURRENCY_LIST_VALUE, "number", vCurrency["value"] or 0);
	end
end
function addCampaignCurrencyHandlers()
	DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST, "onChildDeleted", CurrencyManager.refreshCampaignCurrencies);
	DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST .. ".*." .. CurrencyManager.CAMPAIGN_CURRENCY_LIST_NAME, "onUpdate", CurrencyManager.refreshCampaignCurrencies);
	DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST .. ".*." .. CurrencyManager.CAMPAIGN_CURRENCY_LIST_WEIGHT, "onUpdate", CurrencyManager.refreshCampaignCurrencies);
	DB.addHandler(CurrencyManager.CAMPAIGN_CURRENCY_LIST .. ".*." .. CurrencyManager.CAMPAIGN_CURRENCY_LIST_VALUE, "onUpdate", CurrencyManager.refreshCampaignCurrencies);
end

-- Rebuild the campaign currency dictionary for fast lookup
function refreshCampaignCurrencies()
	_tCampaignCurrencies = {};
	for _,vNode in ipairs(DB.getChildList(CurrencyManager.CAMPAIGN_CURRENCY_LIST)) do
		local sName = StringManager.trim(DB.getValue(vNode, CurrencyManager.CAMPAIGN_CURRENCY_LIST_NAME, ""));
		if (sName or "") ~= "" then
			local vCurrency = {};
			vCurrency.sName = sName;
			vCurrency.nWeight = DB.getValue(vNode, CurrencyManager.CAMPAIGN_CURRENCY_LIST_WEIGHT, 0);
			vCurrency.nValue = DB.getValue(vNode, CurrencyManager.CAMPAIGN_CURRENCY_LIST_VALUE, 0);
			table.insert(_tCampaignCurrencies, vCurrency);
		end
	end
	table.sort(_tCampaignCurrencies, CurrencyManager.sortCampaignCurrencies);
	_bCampaignCurrenciesInit = true;
	CurrencyManager.makeCallback();
end
function sortCampaignCurrencies(a,b)
	if a.nValue ~= b.nValue then
		return a.nValue > b.nValue; -- Descending
	end
	return a.sName < b.sName;
end
-- NOTE: FG windowlist.onSortCompare return values are reversed
--			compared to Lua table.sort return values
function sortCampaignCurrenciesUsingNames(s1, s2)
	local nValue1 = CurrencyManager.getCurrencyValue(s1);
	local nValue2 = CurrencyManager.getCurrencyValue(s2);
	if nValue1 ~= nValue2 then
		return nValue1 < nValue2;
	end
	return s1 > s2;
end

--
-- SETTINGS
--

local _sDefaultCurrency = "";
function setDefaultCurrency(s)
	_sDefaultCurrency = s or "";
end
function getDefaultCurrency()
	return _sDefaultCurrency;
end

local _tDefaultCurrencyPaths = { "coins" };
local _tCustomCurrencyPaths = {};
function setCurrencyPaths(sRecordType, tPaths)
	_tCustomCurrencyPaths[sRecordType] = tPaths;
end
function getCurrencyPaths(sRecordType)
	return _tCustomCurrencyPaths[sRecordType] or _tDefaultCurrencyPaths;
end

local _tDefaultEncumbranceFields = { "amount", "name" };
local _tCustomEncumbranceFields = {};
function setEncumbranceFields(sRecordType, tFields)
	_tCustomEncumbranceFields[sRecordType] = tFields;
end
function getEncumbranceFields(sRecordType)
	return _tCustomEncumbranceFields[sRecordType] or _tDefaultEncumbranceFields;
end

local _tCallbacks = {};
function registerCallback(fn)
	UtilityManager.registerCallback(_tCallbacks, fn);
end
function unregisterCallback(fn)
	UtilityManager.unregisterCallback(_tCallbacks, fn);
end
function makeCallback()
	UtilityManager.performAllCallbacks(_tCallbacks);
end

--
-- LOOKUP
--

function getCurrencies()
	if not _bCampaignCurrenciesInit then
		CurrencyManager.refreshCampaignCurrencies();
	end
	local tSimple = {};
	for _,v in ipairs(_tCampaignCurrencies) do
		table.insert(tSimple, v.sName);
	end
	return tSimple;
end
function getCurrencyRecord(s)
	if not _bCampaignCurrenciesInit then
		CurrencyManager.refreshCampaignCurrencies();
	end
	local sLower = StringManager.trim(s):lower();
	for _,vCurrency in ipairs(_tCampaignCurrencies) do
		if sLower == vCurrency.sName:lower() then
			return vCurrency;
		end
	end
	return nil;
end
function getCurrencyMatch(s)
	if not _bCampaignCurrenciesInit then
		CurrencyManager.refreshCampaignCurrencies();
	end
	local vCurrency = CurrencyManager.getCurrencyRecord(s);
	if vCurrency then
		return vCurrency.sName;
	end
	return nil;
end
function getCurrencyWeight(s)
	if not _bCampaignCurrenciesInit then
		CurrencyManager.refreshCampaignCurrencies();
	end
	local vCurrency = CurrencyManager.getCurrencyRecord(s);
	if vCurrency then
		return vCurrency.nWeight;
	end
	return 0;
end
function getCurrencyValue(s)
	if not _bCampaignCurrenciesInit then
		CurrencyManager.refreshCampaignCurrencies();
	end
	local vCurrency = CurrencyManager.getCurrencyRecord(s);
	if vCurrency then
		return vCurrency.nValue;
	end
	return 0;
end

function populateCharCurrencies(nodeChar)
	if not _bCampaignCurrenciesInit then
		CurrencyManager.refreshCampaignCurrencies();
	end
	for _,vCurrency in ipairs(_tCampaignCurrencies) do
		CurrencyManager.addCharCurrency(nodeChar, vCurrency.sName, 0);
	end
end
function addCharCurrency(nodeChar, sNewCurrency, nNewCurrency)
	local nodeTarget = nil;
	
	-- Check for existing coin match
	local sNewCurrencyLower = sNewCurrency:lower();
	for _, nodeCurrency in ipairs(DB.getChildList(nodeChar, "coins")) do
		local sExistingCurrency = DB.getValue(nodeCurrency, "name", ""); 
		if sNewCurrencyLower == sExistingCurrency:lower() then
			nodeTarget = nodeCurrency;
			break;
		end
	end
	
	-- If no match to existing coins, then find first empty slot
	if not nodeTarget then
		nodeTarget = DB.createChild(DB.getPath(nodeChar, "coins"));
	end
	
	-- If we have a match or an empty slot, then add the currency
	if nodeTarget then
		DB.setValue(nodeTarget, "amount", "number", DB.getValue(nodeTarget, "amount", 0) + nNewCurrency);
		DB.setValue(nodeTarget, "name", "string", sNewCurrency);
	-- Otherwise, add to the other area
	else
		local sMessage = string.format("Unable to create currency slot for character (%s) (%d %s)", DB.getValue(nodeChar, "name", ""), nNewCurrency, sNewCurrency);
		ChatManager.SystemMessage(sMessage);
	end
end

function parseCurrencyString(s, bExistsOnly)
	local nCurrency = 0;
	local sCurrency = nil;

	-- Look for currency suffix (50gp), then currency prefix ($50)
	local sCurrencyAmount;
	sCurrencyAmount, sCurrency = s:match("^%s*([%d,]+)%s*([^%d]*)$");
	if not sCurrencyAmount then 
		sCurrency, sCurrencyAmount = s:match("^%s*([^%d]+)%s*([%d,]+)%s*$");
	end
	if sCurrencyAmount then
		sCurrency = StringManager.trim(sCurrency);
		if bExistsOnly and not CurrencyManager.getCurrencyMatch(sCurrency) then
			return 0, nil;
		end
		sCurrencyAmount = sCurrencyAmount:gsub(",", "");
		nCurrency = tonumber(sCurrencyAmount) or 0;
		if sCurrency == "" then
			sCurrency = CurrencyManager.getDefaultCurrency();
		end
	end

	return nCurrency, sCurrency;
end
