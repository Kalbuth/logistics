 
local SetHelicopter = SET_GROUP:New():FilterPrefixes( "Helicopter" ):FilterStart()
 
-- AICargoDispatcherHelicopter = AI_CARGO_DISPATCHER_HELICOPTER:New( SetHelicopter, SetCargoInfantry, SetDeployZones ) 
--AICargoDispatcherHelicopter:SetHomeZone( ZONE:FindByName( "Home" ) )
-- AICargoDispatcherHelicopter:Start()

-- Logistics parameters definition :

Parameters = {}

-- Prefix used in Logistics Zone Names
Parameters.LogisticsZonePrefixes = {
	"LOGISTICS_ZONE",
}


-- Prefix used in Group names able to do infantry transport tasks
Parameters.InfantryPlayersPrefixes = {
	"01",
	"11",
	"21",
}

-- Prefix used in Group names able to do any transport tasks
Parameters.TransportPlayersPrefixes = {
	"010",
	"110",
	"210",
}

-- Templates of infantry groups - Format : ["<Menu group name>"] = "ME Group template name"
Parameters.InfantryTemplates = {
	["Basic Squad"] = "Infantry1",
	["AA Squad"] = "Infantry2",
}

Parameters.SlingloadPrefixes = {
	"TEMPLATE_SLING_1500",
	"TEMPLATE_SLING_3000",
}

Parameters.SlingloadTemplates = {
	["Cargo 1500kg"] = "TEMPLATE_SLING_1500",
	["Cargo 3000Kg"] = "TEMPLATE_SLING_3000",
}

Parameters.CargoTemplatesWeight = {
	["TEMPLATE_AVENGER"] = 1400,
	["TEMPLATE_LINEBACKER"] = 2700,
	["TEMPLATE_CHAPARRAL"] = 4200,
}

Parameters.CargoTemplatesName = {
	["TEMPLATE_AVENGER"] = "M1097 Avenger",
	["TEMPLATE_LINEBACKER"] = "M6 Linebacker",
	["TEMPLATE_CHAPARRAL"] = "M48 Chaparral with Supply",
}

-- New Class declaration : handling Logistics :

-- LOGISTICS = BASE:New()
LOGISTICS = {
	ClassName = "LOGISTICS",
	GlobalIndex = 1,
}

function LOGISTICS:New( Parameters )
	local self = BASE:Inherit( self, BASE:New() )
	self.SetCargoInfantry = SET_CARGO:New():FilterTypes( "Spawned_Infantry" ):FilterStart()
	self.SetTransportPlayers = SET_GROUP:New():FilterPrefixes( Parameters.TransportPlayersPrefixes ):FilterStart()
	self.SetInfantryPlayers = SET_GROUP:New():FilterPrefixes( Parameters.InfantryPlayersPrefixes ):FilterStart()
	self.SetLogisticsZones = SET_ZONE:New():FilterPrefixes( Parameters.LogisticsZonePrefixes ):FilterStart()
	self.SetSling = SET_STATIC:New():FilterPrefixes( Parameters.SlingloadPrefixes ):FilterStart()
--	self.SetSling = SET_ZONE:New():FilterPrefixes( Parameters.LogisticsZonePrefixes ):FilterOnce()
	self.TroopList = {}
	self.TroopSpawn = {}
	self.SlingSpawn = {}
	self.SlingList = {}
	self.CargoList = {}
	self.PlayerGroups = {}
	self.DeploySpawn = {}
	self.InfantryTemplates = Parameters.InfantryTemplates
	for TroopName, TroopTemplate in pairs(Parameters.InfantryTemplates) do
		self.TroopSpawn[TroopName] = SPAWN
			:NewWithAlias(TroopTemplate, "Spawned_Infantry_" .. TroopName)
	end
	for StaticId, StaticName in pairs( Parameters.SlingloadTemplates ) do
		self.SlingSpawn[StaticName] = SPAWNSTATIC:NewFromStatic(StaticName)
		self.SlingSpawn[StaticName].MenuName = StaticId
	end
	for TemplateName, MenuName in pairs( Parameters.CargoTemplatesName) do 
		self.DeploySpawn[TemplateName] = SPAWN:New(TemplateName)
		self.DeploySpawn[TemplateName].MenuName = MenuName
		self.DeploySpawn[TemplateName].Weight = Parameters.CargoTemplatesWeight[TemplateName]
	end
	self:HandleEvent( EVENTS.PlayerEnterUnit )
	self:HandleEvent( EVENTS.Birth )
end

function LOGISTICS:OnEventPlayerEnterUnit( EventData )
	self:E( "EVENT Fired : " .. routines.utils.oneLineSerialize(EventData))	
	self:ScheduleOnce( 5, self.AddTransportMenu,  self, EventData.IniUnit )
--			function()
--				self:AddTransportMenu( EventData.IniUnit )				
--			end
--		)	
--	local MenuSpawn = MENU_GROUP:New( PlayerGroup, "Transport Tasks")
--	local MenuSpawnTroops = MENU_GROUP_COMMAND:New( PlayerGroup, "Spawn Troops", MenuSpawn, LOGISTICS.SpawnInfGroup, LOGISTICS, PlayerGroup )
end

function LOGISTICS:OnEventBirth( EventData )
	if EventData.IniObjectCategory then
		if ( EventData.IniObjectCategory == 6 ) then
			self:E( routines.utils.oneLineSerialize(EventData) )	
			local CargoName = EventData.IniUnitName
			-- self.SlingList[#self.SlingList + 1] = STATIC:FindByName( CargoName )
			local DCSCargoName = EventData.IniDCSUnitName
			self:E( DCSCargoName )	
			local DCSStatic = StaticObject:getByName( DCSCargoName )
			self:E( routines.utils.oneLineSerialize(DCSStatic) )	
		end
	end
end

function LOGISTICS:AddTransportMenu( IniUnit )
	local PlayerGroup = IniUnit:GetGroup()
	local GroupName = PlayerGroup:GetName()
	self.PlayerGroups[GroupName] = {}
	self.PlayerGroups[GroupName].Group = PlayerGroup
	self:E( "PLAYER entered group : " .. routines.utils.oneLineSerialize(PlayerGroup))
	self.PlayerGroups[GroupName].MenuLogistics = MENU_GROUP:New( PlayerGroup, "Logistics")
	if self.SetInfantryPlayers:IsIncludeObject( PlayerGroup ) then 
		self:AddInfMenu( PlayerGroup )
--		self.PlayerGroups[GroupName].MenuInfantry = MENU_GROUP:New( PlayerGroup, "Spawn Infantry", self.PlayerGroups[GroupName].MenuLogistics)
--		self.PlayerGroups[GroupName].CommandInfantry = {}
--		for InfName, InfSpawn in pairs(self.TroopSpawn) do 
--			self.PlayerGroups[GroupName].CommandInfantry[InfName] = MENU_GROUP_COMMAND:New( PlayerGroup, InfName, self.PlayerGroups[GroupName].MenuInfantry, self.SpawnInfGroup, self, PlayerGroup, InfSpawn, InfName )
--		end
	end
	self.PlayerGroups[GroupName].MenuSling = MENU_GROUP:New( PlayerGroup, "Spawn Cargos", self.PlayerGroups[GroupName].MenuLogistics )
	self.PlayerGroups[GroupName].CommandSling = {}
	for SlingName, SlingSpawn in pairs(self.SlingSpawn) do
		self.PlayerGroups[GroupName].CommandSling[SlingName] = MENU_GROUP_COMMAND:New( PlayerGroup, SlingSpawn.MenuName, self.PlayerGroups[GroupName].MenuSling, self.SpawnSling, self, PlayerGroup, SlingSpawn )
	end
	self.PlayerGroups[GroupName].MenuDeploy = MENU_GROUP:New( PlayerGroup, "Deploy Assets", self.PlayerGroups[GroupName].MenuLogistics )
	self.PlayerGroups[GroupName].CommandDeploy = {}
	for DeployTemplate, DeploySpawn in pairs(self.DeploySpawn) do
		self.PlayerGroups[GroupName].CommandDeploy[DeployTemplate] = MENU_GROUP_COMMAND:New( PlayerGroup, DeploySpawn.MenuName, self.PlayerGroups[GroupName].MenuDeploy, self.DeployAsset, self, PlayerGroup, DeploySpawn )
	end
	self.PlayerGroups[GroupName].CommandLoad = MENU_GROUP_COMMAND:New( PlayerGroup, "Load Nearest Cargo", self.PlayerGroups[GroupName].MenuLogistics, self.LoadSling, self, PlayerGroup )
	
--	local MenuSpawnTroops = MENU_GROUP_COMMAND:New( PlayerGroup, "Spawn Troops", MenuSpawn, LOGISTICS.SpawnInfGroup, LOGISTICS, PlayerGroup )
end

function LOGISTICS:AddInfMenu( PlayerGroup )
	local GroupName = PlayerGroup:GetName()
	self.PlayerGroups[GroupName].MenuInfantry = MENU_GROUP:New( PlayerGroup, "Spawn Infantry", self.PlayerGroups[GroupName].MenuLogistics)
	self.PlayerGroups[GroupName].CommandInfantry = {}
	for InfName, InfSpawn in pairs(self.TroopSpawn) do 
		self.PlayerGroups[GroupName].CommandInfantry[InfName] = MENU_GROUP_COMMAND:New( PlayerGroup, InfName, self.PlayerGroups[GroupName].MenuInfantry, self.SpawnInfGroup, self, PlayerGroup, InfSpawn, InfName )
	end
end

function LOGISTICS:AddUnboardMenu( PlayerGroup )
	local GroupName = PlayerGroup:GetName()
	self.PlayerGroups[GroupName].CommandUnboard = MENU_GROUP_COMMAND:New( PlayerGroup, "Unboard Cargo", self.PlayerGroups[GroupName].MenuLogistics, self.UnboardCargo, self, PlayerGroup )
end

function LOGISTICS:UnboardCargo( PlayerGroup )
	local GroupName = PlayerGroup:GetName()
	PlayerGroup.Cargo:UnBoard()
	self.PlayerGroups[GroupName].CommandUnboard:Remove()
	self:AddInfMenu( PlayerGroup )
end

function LOGISTICS:LoadSling( PlayerGroup )
	local dist = 10000
	local PlayerCoord = PlayerGroup:GetCoordinate()
	local SlingCoord = false
	local NearSling = false
	for StaticID, StaticData in pairs(self.CargoList) do
		local StaticCoord = StaticData:GetCoordinate()
		if ( StaticCoord:Get3DDistance( PlayerCoord ) < dist ) then
			dist = StaticCoord:Get3DDistance( PlayerCoord )
			SlingCoord = StaticCoord
			NearSling = StaticData
		end
	end
	if ( dist < 50 ) then
		MESSAGE:New("Loading Crate."):ToGroup( PlayerGroup )
		local Carrier = PlayerGroup:GetUnits()[1]
		NearSling:Load( Carrier )
		self.PlayerGroups[GroupName].CommandLoad:Remove()
	else
		MESSAGE:New("No nearby crate found. Stand less than 50m from one."):ToGroup( PlayerGroup )
	end
end

function LOGISTICS:SpawnInfGroup( PlayerGroup, InfSpawn, InfName )
	self:E("Spawning troops!")
	local isInZone = false
	local LocalZone = {}
	for ZoneName, ZoneData in pairs(self.SetLogisticsZones.Set) do
		if PlayerGroup:IsCompletelyInZone( ZoneData ) then 
			isInZone = true 
			LocalZone = ZoneData
		end
	end
	if isInZone then 
		local InfGroup = InfSpawn:SpawnInZone( LocalZone , false )
		self.TroopList[#self.TroopList + 1] = InfGroup
		self.LatestTroops = self.TroopList[#self.TroopList]
		local Carrier = PlayerGroup:GetUnits()[1]
		local PlayerName = Carrier:GetPlayerName()
		PlayerGroup.Cargo = CARGO_GROUP:New( InfGroup, "Spawned_Infantry", "Spawned_Infantry_by_" .. PlayerName )
		PlayerGroup.Cargo:Board( Carrier )
		local GroupName = PlayerGroup:GetName()
		self.PlayerGroups[GroupName].MenuInfantry:Remove()
		self:AddUnboardMenu( PlayerGroup )
		MESSAGE:New(InfName .. " is coming on board, hold on.", 10, "Logistics"):ToGroup( PlayerGroup )
	else
		MESSAGE:New("You are not in any Logistics Zone.", 10, "Logistics"):ToGroup( PlayerGroup )
	end
end

function LOGISTICS:SpawnSling( PlayerGroup, SlingSpawn )
	local isInZone = false
	local LocalZone = {}
	for ZoneName, ZoneData in pairs(self.SetLogisticsZones.Set) do
		if PlayerGroup:IsCompletelyInZone( ZoneData ) then 
			isInZone = true 
			LocalZone = ZoneData
		end
	end
	if isInZone then 
		local LastSling = SlingSpawn:SpawnFromZone( LocalZone, 0 )
		local plyr = PlayerGroup:GetPlayerUnits()[1]
		local slingName = plyr:GetPlayerName() .. "'s " .. SlingSpawn.MenuName
		self.CargoList[plyr:GetPlayerName()] = CARGO_CRATE:New( LastSling, "Supplies", slingName )
		self:RegisterStatic( LastSling )
	else
		MESSAGE:New("You are not in any Logistics Zone.", 10, "Logistics"):ToGroup( PlayerGroup )
	end
end

function LOGISTICS:RegisterStatic( Object )
	for paramID, paramData in pairs( Object ) do
		self:E("Static parameter : " .. routines.utils.oneLineSerialize(paramID))
	end
	self.SlingList[#self.SlingList + 1] = Object
	self:E("Adding Static into Zone : " .. routines.utils.oneLineSerialize(self.SlingList[#self.SlingList]))

end

function LOGISTICS:DeployAsset( PlayerGroup, DeploySpawn )
	local PlayerCoord = PlayerGroup:GetCoordinate()
	local TotalWeight = 0
	local SlingList = {}
	for StaticID, StaticData in pairs(self.CargoList) do
		local StaticCoord = StaticData:GetCoordinate()
		if ( StaticCoord:Get3DDistance( PlayerCoord ) < 100 ) then
			local StaticWeight = 0
			local DCSStatic = StaticData.CargoObject:GetDCSObject()
			if DCSStatic then 
				StaticWeight = DCSStatic:getCargoWeight()
			end
			TotalWeight = TotalWeight + StaticWeight
			self:E("Total Weight : " .. TotalWeight )
			SlingList[#SlingList + 1] = StaticData
		end
	end
	local NeededWeight = DeploySpawn.Weight
	if ( TotalWeight > NeededWeight ) then
		MESSAGE:New("Deploying " .. DeploySpawn.MenuName .. ".", 10, "Logistics"):ToGroup( PlayerGroup )
		local PlayerZone = ZONE_GROUP:New( "DEPLOY_ZONE_" .. PlayerGroup:GetName(), PlayerGroup , 100 )
		DeploySpawn:SpawnInZone( PlayerZone , true )
		for id, Static in pairs(SlingList) do
			Static.CargoObject:Destroy()
		end
	else
		MESSAGE:New("Not enough supply nearby to deploy " .. DeploySpawn.MenuName .. " Bring more.", 10, "Logistics"):ToGroup( PlayerGroup )
	end
end

Logistics = LOGISTICS:New( Parameters )
