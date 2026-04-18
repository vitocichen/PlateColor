local _, ns = ...

--[[
	友方玩家图标模块
	仿照 BetterBlizzPlates 架构：
	- 使用 NAME_PLATE_UNIT_ADDED / NAME_PLATE_UNIT_REMOVED 事件驱动
	- 完全不触碰敌方姓名版
	- 使用 SetIgnoreParentAlpha(true) 让图标独立
	- 用 SetText("") 隐藏名字而非 SetAlpha(0)
]]

-- friendlyIconMode: 0=不使用, 1=职业图标, 2=角色图标
-- onlyName: true 时为名字模式（暴雪CVar控制）

local CLASS_ICON_ATLAS = {
	["WARRIOR"] = "classicon-warrior",
	["PALADIN"] = "classicon-paladin",
	["HUNTER"] = "classicon-hunter",
	["ROGUE"] = "classicon-rogue",
	["PRIEST"] = "classicon-priest",
	["DEATHKNIGHT"] = "classicon-deathknight",
	["SHAMAN"] = "classicon-shaman",
	["MAGE"] = "classicon-mage",
	["WARLOCK"] = "classicon-warlock",
	["MONK"] = "classicon-monk",
	["DRUID"] = "classicon-druid",
	["DEMONHUNTER"] = "classicon-demonhunter",
	["EVOKER"] = "classicon-evoker",
}

local ICON_SIZE = 30
local eventFrame = CreateFrame("Frame")

-- 判断单位是否为友方（reaction >= 5）
local function IsFriendlyUnit(unit)
	if not unit then return false end
	local reaction = UnitReaction(unit, "player")
	return reaction and reaction >= 5
end

-- 创建或获取图标框体
local function GetOrCreateIcon(frame)
	if frame.PCFriendlyIcon then return frame.PCFriendlyIcon end

	local icon = CreateFrame("Frame", nil, frame)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
	icon:SetIgnoreParentAlpha(true) -- 关键：不受父级透明度影响
	icon:SetFrameStrata("HIGH")

	icon.texture = icon:CreateTexture(nil, "OVERLAY")
	icon.texture:SetAllPoints()

	icon:Hide()
	frame.PCFriendlyIcon = icon
	return icon
end

-- 处理姓名版添加事件
local function HandleNamePlateAdded(unit)
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate then return end
	local frame = nameplate.UnitFrame
	if not frame or frame:IsForbidden() then return end

	-- 只处理友方玩家，完全跳过敌方和NPC
	if not IsFriendlyUnit(unit) or not UnitIsPlayer(unit) then
		-- 如果之前有图标（比如决斗结束变回友方），确保隐藏
		if frame.PCFriendlyIcon then
			frame.PCFriendlyIcon:Hide()
		end
		-- 恢复可能被修改的名字
		if frame.PCFriendlyIconNameHidden then
			frame.PCFriendlyIconNameHidden = nil
			-- 名字会在暴雪的 CompactUnitFrame_UpdateName 中自然恢复
		end
		return
	end

	local mode = PlateColorDB.friendlyIconMode or 0
	if mode == 0 then
		-- 不使用友方图标，确保清理
		if frame.PCFriendlyIcon then
			frame.PCFriendlyIcon:Hide()
		end
		if frame.PCFriendlyIconNameHidden then
			frame.PCFriendlyIconNameHidden = nil
		end
		return
	end

	local icon = GetOrCreateIcon(frame)

	if mode == 1 then
		-- 职业图标
		local _, classFile = UnitClass(unit)
		if classFile and CLASS_ICON_ATLAS[classFile] then
			icon.texture:SetAtlas(CLASS_ICON_ATLAS[classFile])
			icon:Show()
		else
			icon:Hide()
			return
		end
	elseif mode == 2 then
		-- 角色图标（3D头像）
		if icon.model == nil then
			icon.model = CreateFrame("PlayerModel", nil, icon)
			icon.model:SetAllPoints()
			icon.model:SetPortraitZoom(1)
		end
		icon.texture:SetTexture(nil)
		icon.model:SetUnit(unit)
		icon.model:Show()
		icon:Show()
	end

	-- 隐藏名字：使用 SetText("") 而非 SetAlpha(0)
	if frame.name then
		frame.name:SetText("")
		frame.PCFriendlyIconNameHidden = true
	end

	-- 隐藏功能文本（公会名等）
	if frame.NpcFuntext then
		frame.NpcFuntext:Hide()
	end
end

-- 处理姓名版移除事件 —— 完整清理
local function HandleNamePlateRemoved(unit)
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate then return end
	local frame = nameplate.UnitFrame
	if not frame or frame:IsForbidden() then return end

	-- 隐藏图标
	if frame.PCFriendlyIcon then
		frame.PCFriendlyIcon:Hide()
		-- 清理3D模型
		if frame.PCFriendlyIcon.model then
			frame.PCFriendlyIcon.model:ClearModel()
			frame.PCFriendlyIcon.model:Hide()
		end
	end

	-- 恢复名字显示
	if frame.PCFriendlyIconNameHidden then
		frame.PCFriendlyIconNameHidden = nil
		-- 名字 alpha 保持为1，文本会在暴雪下次 UpdateName 时自动恢复
		if frame.name then
			frame.name:SetAlpha(1)
		end
	end

	-- 恢复血条容器透明度
	if frame.HealthBarsContainer then
		frame.HealthBarsContainer:SetAlpha(1)
	end
end

-- 刷新所有已存在的姓名版（设置变更时调用）
function ns.RefreshFriendlyIcons()
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		if nameplate.UnitFrame and not nameplate.UnitFrame:IsForbidden() then
			local unit = nameplate.UnitFrame.unit
			if unit then
				-- 先清理再重新应用
				HandleNamePlateRemoved(unit)
				HandleNamePlateAdded(unit)
			end
		end
	end
end

-- 注册事件
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		HandleNamePlateAdded(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		HandleNamePlateRemoved(unit)
	end
end)

-- Hook CompactUnitFrame_UpdateName 仅用于保持名字隐藏
-- 不修改任何 alpha，只在友方图标激活时重新清空名字文本
hooksecurefunc("CompactUnitFrame_UpdateName", function(unitFrame)
	if unitFrame:IsForbidden() then return end
	if not unitFrame.unit then return end
	if not string.match(unitFrame.unit, "nameplate") then return end

	-- 只处理已经被我们标记的友方图标姓名版
	if not unitFrame.PCFriendlyIconNameHidden then return end

	local mode = PlateColorDB.friendlyIconMode or 0
	if mode == 0 then return end

	-- 再次隐藏名字（暴雪的 UpdateName 会恢复名字文本）
	if unitFrame.name then
		unitFrame.name:SetText("")
	end
	if unitFrame.NpcFuntext then
		unitFrame.NpcFuntext:Hide()
	end
end)
