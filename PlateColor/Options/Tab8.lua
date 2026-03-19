local addonName,ns = ...
local L = ns.L
local DB = ns.PlateColorDB

ns.event("PLAYER_ENTERING_WORLD", function()
--分页8滚动框架
local ConFramescrollFrame8 = CreateFrame("ScrollFrame", nil, ns.tabframe8, "UIPanelScrollFrameTemplate")
ConFramescrollFrame8:SetPoint("TOPLEFT", ns.tabframe8, "TOPLEFT", 4, -5)
ConFramescrollFrame8:SetPoint("BOTTOMRIGHT", ns.tabframe8, "BOTTOMRIGHT", -30, 5)
--分页8滚动内容
local ConFrame8 = CreateFrame("Frame", nil, ConFramescrollFrame8)
ConFrame8:SetSize(670,560)
ConFramescrollFrame8:SetScrollChild(ConFrame8)
ns.Y[8] = 0	--设置起始位置

local petTitle = ns.AddSetTiText(ConFrame8,8,L["敌方宠物"])
local petPlateEnable = ns.AddSetClickB(ConFrame8,8,L["启用敌方宠物自定义"],L["启用敌方宠物自定义"],"petPlateEnable",ns.SetPoints)

local petNormal = ns.AddSetTiText(ConFrame8,8,L["宠物未选中设置"])
local petHpWidth = ns.AddSetSlider(ConFrame8,8,L["宠物血条宽度"],L["宠物血条宽度鼠标提示"],5,50,1,"%d","petHpWidth",ns.SetPoints)
local petHpHeight = ns.AddSetSlider(ConFrame8,8,L["宠物血条高度"],L["宠物血条高度鼠标提示"],3,30,1,"%d","petHpHeight",ns.SetPoints)
local petCastBarHeight = ns.AddSetSlider(ConFrame8,8,L["宠物施法条高度"],L["宠物施法条高度鼠标提示"],3,30,1,"%d","petCastBarHeight",ns.SetPoints)
local petCastTextScale = ns.AddSetSlider(ConFrame8,8,L["宠物施法文本大小"],L["宠物施法文本大小鼠标提示"],5,30,1,"%d","petCastTextScale",ns.SetPoints)
local petCastTargetScale = ns.AddSetSlider(ConFrame8,8,L["宠物施法目标大小"],L["宠物施法目标大小鼠标提示"],5,30,1,"%d","petCastTargetScale",ns.SetPoints)
local petAlpha = ns.AddSetSlider(ConFrame8,8,L["宠物透明度"],L["宠物透明度鼠标提示"],0.1,1,0.05,"%.2f","petAlpha",ns.SetPoints)

local petSelected = ns.AddSetTiText(ConFrame8,8,L["宠物选中设置"])
local petSelectedHpWidth = ns.AddSetSlider(ConFrame8,8,L["选中时宠物血条宽度"],L["选中时宠物血条宽度鼠标提示"],5,50,1,"%d","petSelectedHpWidth",ns.SetPoints)
local petSelectedHpHeight = ns.AddSetSlider(ConFrame8,8,L["选中时宠物血条高度"],L["选中时宠物血条高度鼠标提示"],3,30,1,"%d","petSelectedHpHeight",ns.SetPoints)
local petSelectedCastBarHeight = ns.AddSetSlider(ConFrame8,8,L["选中时宠物施法条高度"],L["选中时宠物施法条高度鼠标提示"],3,30,1,"%d","petSelectedCastBarHeight",ns.SetPoints)
local petSelectedAlpha = ns.AddSetSlider(ConFrame8,8,L["选中时宠物透明度"],L["选中时宠物透明度鼠标提示"],0.1,1,0.05,"%.2f","petSelectedAlpha",ns.SetPoints)

local petColorTitle = ns.AddSetTiText(ConFrame8,8,L["宠物颜色设置"])
local petBarColor = ns.AddClickColor(ConFrame8,8,L["宠物血条颜色"],L["宠物血条颜色鼠标提示"],"petBarColorEnable","petBarColor",ns.UpdateHpbarColor)
local petNameColor = ns.AddClickColor(ConFrame8,8,L["宠物名字颜色"],L["宠物名字颜色鼠标提示"],"petNameColorEnable","petNameColor",ns.SetNameColor)

end)
