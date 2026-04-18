local _, ns = ...

--[[
	友方玩家图标模块
	仿照 BetterBlizzPlates 架构：
	- 使用 NAME_PLATE_UNIT_ADDED / NAME_PLATE_UNIT_REMOVED 事件驱动
	- 完全不触碰敌方姓名版
	- 使用 SetIgnoreParentAlpha(true) 让图标独立
	- 用 SetText("") 隐藏名字而非 SetAlpha(0)
	- 用 SetAlpha(0) 隐藏血条（仿BBP的HideFriendlyHealthbar）
]]

-- friendlyIconMode: 0=不使用(显示名字), 1=职业图标, 2=专精图标（治疗/坦克/DPS都显示对应专精icon）

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

-- 专精图标缓存：GUID -> {specID = xxx, iconID = xxx}
local SpecCache = {}
-- 等待 INSPECT_READY 的单位列表：GUID -> unit
local PendingInspect = {}

-- BBP 风格尺寸（参考 BBP classIcon.lua 的 Circle 分支）
local FRAME_SIZE    = 30   -- 外层 frame（= border SetAllPoints 的范围）
local ICON_SIZE     = 26   -- 实际图标（略小于 frame，给 border 留出金边空间）
local HIGHLIGHT_SIZE = 40  -- 目标高亮环尺寸（略大于 frame）

local eventFrame = CreateFrame("Frame")

-- 判断单位是否为友方（reaction >= 5）
local function IsFriendlyUnit(unit)
	if not unit then return false end
	local reaction = UnitReaction(unit, "player")
	return reaction and reaction >= 5
end

-- 获取单位专精 icon（返回 iconID 或 nil）
-- 策略：
-- 1) 自己 → GetSpecializationInfo(GetSpecialization())
-- 2) 同队队友 → GetInspectSpecialization(unit) 通常直接有值（队伍同步）
-- 3) 其他友方玩家 → NotifyInspect 异步请求，等 INSPECT_READY 回填
local function GetUnitSpecIcon(unit)
	if not unit or not UnitIsPlayer(unit) then return nil end

	-- 自己
	if UnitIsUnit(unit, "player") then
		local currentSpec = GetSpecialization()
		if currentSpec then
			local _, _, _, iconID = GetSpecializationInfo(currentSpec)
			return iconID
		end
		return nil
	end

	local guid = UnitGUID(unit)
	if not guid then return nil end

	-- 缓存命中
	if SpecCache[guid] then
		return SpecCache[guid].iconID
	end

	-- 查 InspectSpecialization（队友同步的数据，通常直接有）
	local specID = GetInspectSpecialization(unit)
	if specID and specID > 0 then
		local _, _, _, iconID = GetSpecializationInfoByID(specID)
		if iconID then
			SpecCache[guid] = { specID = specID, iconID = iconID }
			return iconID
		end
	end

	-- 没查到：发起 inspect 请求，等 INSPECT_READY 回来后刷新
	if CanInspect(unit) and not PendingInspect[guid] then
		PendingInspect[guid] = unit
		NotifyInspect(unit)
	end

	return nil
end

-- 创建或获取图标框体（仿 BBP：icon + mask + border + highlightSelect）
local function GetOrCreateIcon(frame)
	if frame.PCFriendlyIcon then return frame.PCFriendlyIcon end

	local icon = CreateFrame("Frame", nil, frame)
	icon:SetSize(FRAME_SIZE, FRAME_SIZE)
	icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
	icon:SetIgnoreParentAlpha(true) -- 关键：不受父级透明度影响
	icon:SetFrameStrata("HIGH")

	-- 1) 图标本体（BORDER 层，实际内容）
	icon.texture = icon:CreateTexture(nil, "BORDER")
	icon.texture:SetSize(ICON_SIZE, ICON_SIZE)
	icon.texture:SetPoint("CENTER", icon, "CENTER", 0, 0)
	-- 扩展采样区域避免图标边缘被裁切（BBP 同款 trick）
	icon.texture:SetTexCoord(-0.06, 1.05, -0.06, 1.05)

	-- 2) 圆形遮罩（用暴雪内置的 CircleMaskScalable，比 TempPortraitAlphaMask 边缘更干净）
	local mask = icon:CreateMaskTexture()
	mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(ICON_SIZE, ICON_SIZE)
	mask:SetPoint("CENTER", icon.texture)
	icon.texture:AddMaskTexture(mask)
	icon.mask = mask

	-- 3) 金色边框（BBP 同款 AutoQuest-badgeborder）
	icon.border = icon:CreateTexture(nil, "OVERLAY", nil, 6)
	icon.border:SetAtlas("AutoQuest-badgeborder")
	icon.border:SetAllPoints(icon)

	-- 4) 目标高亮环（charactercreate-ring-select，金色 1,0.88,0）
	icon.highlight = icon:CreateTexture(nil, "OVERLAY", nil, 7)
	icon.highlight:SetAtlas("charactercreate-ring-select")
	icon.highlight:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.highlight:SetSize(HIGHLIGHT_SIZE, HIGHLIGHT_SIZE)
	icon.highlight:SetVertexColor(1, 0.88, 0)
	icon.highlight:Hide()

	icon:Hide()
	frame.PCFriendlyIcon = icon
	return icon
end

-- 隐藏友方玩家的血条（仿照BBP的SetAlpha(0)方式，不依赖暴雪CVar和showOnlyName）
local function HideFriendlyPlayerBars(frame)
	if frame.HealthBarsContainer then
		frame.HealthBarsContainer:SetAlpha(0)
	end
	if frame.selectionHighlight then
		frame.selectionHighlight:SetAlpha(0)
	end
	if frame.castBar then
		frame.castBar:SetAlpha(0)
	end
	frame.PCFriendlyBarsHidden = true
end

-- 恢复血条显示（友方→敌方切换时使用）
local function RestoreFriendlyPlayerBars(frame)
	if not frame.PCFriendlyBarsHidden then return end
	if frame.HealthBarsContainer then
		frame.HealthBarsContainer:SetAlpha(1)
	end
	if frame.selectionHighlight then
		frame.selectionHighlight:SetAlpha(1)
	end
	if frame.castBar then
		frame.castBar:SetAlpha(1)
	end
	frame.PCFriendlyBarsHidden = nil
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
		end
		-- 恢复血条
		RestoreFriendlyPlayerBars(frame)
		return
	end

	-- 友方玩家：始终隐藏血条（不论图标模式还是名字模式）
	HideFriendlyPlayerBars(frame)

	local mode = PlateColorDB.friendlyIconMode or 0
	if mode == 0 then
		-- 名字模式：不显示图标，只显示名字（血条已隐藏）
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
			-- 职业图标用 atlas 后要重新应用 TexCoord 扩展
			icon.texture:SetTexCoord(-0.06, 1.05, -0.06, 1.05)
			icon:Show()
		else
			icon:Hide()
			return
		end
	elseif mode == 2 then
		-- 专精图标：治疗/坦克/DPS 都显示各自专精 icon
		local iconID = GetUnitSpecIcon(unit)
		if iconID then
			icon.texture:SetTexture(iconID)
			-- 专精图标是方形贴图，用扩展 TexCoord 消除边缘裁切（同职业图标）
			icon.texture:SetTexCoord(-0.06, 1.05, -0.06, 1.05)
		else
			-- 专精未知：临时回退到职业图标（等 INSPECT_READY 再刷新成专精）
			local _, classFile = UnitClass(unit)
			if classFile and CLASS_ICON_ATLAS[classFile] then
				icon.texture:SetAtlas(CLASS_ICON_ATLAS[classFile])
				icon.texture:SetTexCoord(-0.06, 1.05, -0.06, 1.05)
			else
				icon:Hide()
				return
			end
		end
		icon:Show()
	end

	-- 目标高亮环：仅在该姓名板为当前 target 时显示
	if icon.highlight then
		if UnitIsUnit(unit, "target") then
			icon.highlight:Show()
		else
			icon.highlight:Hide()
		end
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
		if frame.PCFriendlyIcon.highlight then
			frame.PCFriendlyIcon.highlight:Hide()
		end
	end

	-- 恢复名字显示
	if frame.PCFriendlyIconNameHidden then
		frame.PCFriendlyIconNameHidden = nil
		if frame.name then
			frame.name:SetAlpha(1)
		end
	end

	-- 恢复血条
	RestoreFriendlyPlayerBars(frame)
end

-- 更新所有已显示友方图标的 target 高亮环
local function UpdateAllTargetHighlights()
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		local frame = nameplate.UnitFrame
		if frame and not frame:IsForbidden() and frame.PCFriendlyIcon and frame.PCFriendlyIcon:IsShown() then
			local unit = frame.unit
			if unit and frame.PCFriendlyIcon.highlight then
				if UnitIsUnit(unit, "target") then
					frame.PCFriendlyIcon.highlight:Show()
				else
					frame.PCFriendlyIcon.highlight:Hide()
				end
			end
		end
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
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "NAME_PLATE_UNIT_ADDED" then
		HandleNamePlateAdded(arg1)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		HandleNamePlateRemoved(arg1)
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdateAllTargetHighlights()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		-- arg1 是切换专精的 unit；清掉它的缓存，后续重新查询
		if arg1 then
			local guid = UnitGUID(arg1)
			if guid then SpecCache[guid] = nil end
		end
	elseif event == "INSPECT_READY" then
		-- arg1 是 GUID
		local guid = arg1
		if PendingInspect[guid] then
			PendingInspect[guid] = nil
			-- 查找当前所有姓名板匹配 GUID（unit token 可能已变）
			for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
				local npFrame = nameplate.UnitFrame
				if npFrame and not npFrame:IsForbidden() and npFrame.unit and UnitGUID(npFrame.unit) == guid then
					-- 用当前实际 unit token 重新查专精
					local specID = GetInspectSpecialization(npFrame.unit)
					if specID and specID > 0 then
						local _, _, _, iconID = GetSpecializationInfoByID(specID)
						if iconID then
							SpecCache[guid] = { specID = specID, iconID = iconID }
						end
					end
					-- 重新走 Added 流程刷新图标
					HandleNamePlateAdded(npFrame.unit)
					break
				end
			end
		end
	end
end)

-- Hook OnUnitFactionChanged：友方→敌方时清理图标和恢复血条
-- 仅做清理操作，不做任何设置/初始化，不影响敌方姓名版
hooksecurefunc(NamePlateUnitFrameMixin, "OnUnitFactionChanged", function(self)
	if not self.unit then return end
	if self:IsForbidden() then return end
	if not string.match(self.unit, "nameplate") then return end

	-- 只在单位变成非友方时做清理
	if not IsFriendlyUnit(self.unit) then
		-- 隐藏图标
		if self.PCFriendlyIcon then
			self.PCFriendlyIcon:Hide()
			if self.PCFriendlyIcon.highlight then
				self.PCFriendlyIcon.highlight:Hide()
			end
		end
		-- 恢复名字
		if self.PCFriendlyIconNameHidden then
			self.PCFriendlyIconNameHidden = nil
			if self.name then
				self.name:SetAlpha(1)
			end
		end
		-- 恢复血条
		RestoreFriendlyPlayerBars(self)
	else
		-- 单位变成友方了（如决斗结束），重新应用图标
		HandleNamePlateAdded(self.unit)
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

-- 持续压制友方施法条
-- 原因：HideFriendlyPlayerBars 里的 SetAlpha(0) 只在 UNIT_ADDED 触发一次，
-- 施法开始时暴雪的 NamePlateCastingBarMixin:OnEvent(UNIT_SPELLCAST_START) 会
-- 重新 Show() 并恢复 alpha，导致友方施法条又冒出来。
-- 解法：hook OnShow，凡是当前姓名版已被标记 PCFriendlyBarsHidden 的，直接把
-- 施法条 alpha 压回 0（不调用 Hide，避免破坏暴雪内部事件循环状态）。
local function SuppressCastBarIfFriendly(castBar)
	if not castBar or castBar:IsForbidden() then return end
	local unit = castBar.unit
	if not unit or not string.match(unit, "nameplate") then return end
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate then return end
	local frame = nameplate.UnitFrame
	if frame and frame.PCFriendlyBarsHidden then
		castBar:SetAlpha(0)
	end
end

hooksecurefunc(NamePlateCastingBarMixin, "OnEvent", function(self)
	SuppressCastBarIfFriendly(self)
end)

hooksecurefunc(NamePlateCastingBarMixin, "OnShow", function(self)
	SuppressCastBarIfFriendly(self)
end)
