--!strict
--!optimize 2
--!native
--/ Citadel/Utils.luau (Client) (a. HeartOfIrons)
--/ Utilities and general-purpose tools
local Utils = {Version = "0.1.26:P"}
local Servos = {
	TweenService = game:GetService("TweenService");
	TextService = game:GetService("TextService");
	RunService = game:GetService("RunService");
	Lighting = game:GetService("Lighting")
}

type Properties = {[string]: any}
local TINew = TweenInfo.new
local INew = Instance.new
local V3New = Vector3.new
local TIns, TCat, TFrz = table.insert, table.concat, table.freeze
local MFlr, MClp, MRnd, MRand = math.floor, math.clamp, math.round, math.random
local MExp, MAbs = math.exp, math.abs
local TKDly, TKSpn = task.delay, task.spawn
local CRYield, CREnb = coroutine.yield, coroutine.running
local FromEnum = Font.fromEnum
local EFont = Enum.Font
local Clock = os.clock
local Heart = Servos.RunService.Heartbeat

local TBParams = INew("GetTextBoundsParams")

--/ Shortcuts

Utils.FaceNorms = TFrz({V3New(1, 0, 0); V3New(-1, 0, 0); V3New(0, 1, 0); V3New(0, -1, 0); V3New(0, 0, 1); V3New(0, 0, -1)})

--/ Vectors

function Utils.SnapVec(Position: Vector3, Size: number)
	assert(typeof(Size) == "number", "Size must be a number")
	local Snap = Utils.Snap
	return V3New(Snap(Position.X, Size), Snap(Position.Y, Size), Snap(Position.Z, Size))
end

--/ Numbers

function Utils.Snap(Value: number, Size: number): number
	assert(typeof(Size) == "number", "Size must be a number")
	return MRnd(Value / Size) * Size
end
function Utils.Round(Number: number, Digits: number): number
	local Mult = 10 ^ Digits
	return MRnd(Number * Mult) / Mult
end
function Utils.StepClamp(Value: number, Step: number, Min: number, Max: number): number
	return MClp((MRnd((Value - Min) / Step) * Step + Min), Min, Max)
end
function Utils.InvLerp(Value: number, Min: number, Max: number): number
	return (Value - Min) / (Max - Min)
end
function Utils.ExpAlpha(Speed: number, Delta: number): number
	return 1 - MExp(-Speed * Delta)
end
function Utils.Lerp(Alpha: number, Bravo: number, Time: number): number
	return Alpha + (Bravo - Alpha) * Time
end
function Utils.SurfOffset(Normal: Vector3, Half: Vector3): Vector3
	return V3New(MAbs(Normal.X) * Half.X, MAbs(Normal.Y) * Half.Y, MAbs(Normal.Z) * Half.Z)
end
function Utils.SqrtDist(Alpha: Vector3, Bravo: Vector3): number
	local Delta = Alpha - Bravo
	return Delta:Dot(Delta)
end

--/ Animations

function Utils.QTween(Object, Properties: Properties, Info: TweenInfo | number?): Tween
	Info = typeof(Info) == "number" and TINew(Info) or Info or TINew(0.5)
	local Tween = Servos.TweenService:Create(Object, (Info :: TweenInfo), Properties)
	Tween:Play()
	return Tween
end

--/ Text

function Utils.MeasureHeight(Text: string | TextLabel, Size: number, FontObj: Font | nil, Width: number): number
	FontObj = FontObj or typeof(Text) == "Instance" and Text.Font or FromEnum(EFont.Montserrat)
	Utils.QEdit(TBParams, {Text = typeof(Text) == "Instance" and Text.Text or Text; Size = Size; Font = FontObj; Width = Width})
	return Servos.TextService:GetTextBoundsAsync(TBParams).Y
end

function Utils.ToString(Object: any): string
	if typeof(Object) == "Instance" or typeof(Object) == "EnumItem" then
		return Object.Name
	elseif typeof(Object) == "table" then
		local Parts = {}
		for _, Value in Object do
			TIns(Parts, Utils.ToString(Value))
		end
		return TCat(Parts, ", ")
	elseif typeof(Object) == "string" then
		return Object
	end
	return tostring(Object)
end

--/ Instances

function Utils.QEdit(Object: Instance | {Instance}, Properties: Properties, ign: any): Instance | {Instance}
	if typeof(Object) == "table" then
		for _, Object in Object do Utils.QEdit(Object, Properties) end
		return Object
	end
	for Key, Value in Properties do
		local OK, Res = pcall(function()
			Object[Key] = Value
		end)
		if not OK then
			warn(`[UT.QEdit] Failed to write to property '{Key}' in {Object}`)
		end
	end
	if ign then
		warn(`QEdit does not handle parenting ({tostring(ign)}). Parenting must be handled within 'Properties' argument.`)
	end
	return Object
end

function Utils.QCreate(Class: string, Properties: Properties?, Parent: Instance?): any
	return Utils.QEdit(INew(Class, Parent or game), Properties or {})
end

function Utils.QWeld(I1: Instance, I2: Instance, Class: "WeldConstraint" | "Weld"): WeldConstraint | Weld
	Utils.QEdit({I1, I2}, {Anchored = false})
	return Utils.QCreate(Class or "WeldConstraint", {Part0 = I1, Part1 = I2}, I1)
end

--/ Attributes

function Utils.WaitForAttr(Object: Instance, Identifier: string, Time: number?): any
	local Value = Object:GetAttribute(Identifier)
	if Value ~= nil then return Value end
	Time = Time or 10
	local Signal = Object:GetAttributeChangedSignal(Identifier)
	local Thread, Completed = CREnb(), false
	local Connection: RBXScriptConnection
	Connection = Signal:Connect(function()
		if Completed then return end
		local Current = Object:GetAttribute(Identifier)
		if Current ~= nil then
			Completed = true
			Connection:Disconnect()
			TKSpn(Thread)
		end
	end)
	TKDly(Time, function()
		if Completed then return end
		Completed = true
		Connection:Disconnect()
		warn(`Possible infinite yield for '{Identifier}' on '{Object.Name}'`)
		TKSpn(Thread)
	end)
	CRYield()
	return Object:GetAttribute(Identifier)
end

--/ Tables

function Utils.FisherShuffle(Table: {any}): {any}
	for Index = #Table, 2, -1 do
		local Rnd = MRand(1, Index)
		Table[Index], Table[Rnd] = Table[Rnd], Table[Index]
	end
	return Table
end

function Utils.Copy(Table: {any}): {any}
	assert(typeof(Table) == "table")
	local Result = {}
	for Key, Value in pairs(Table) do
		if typeof(Value) == "table" then
			Result[Key] = Utils.Copy(Value)
		else
			Result[Key] = Value
		end
	end
	return Result
end

function Utils.QMerge(From: {any}, To: {any}): {any}
	for Key, Value in pairs(From) do
		local Previous = To[Key]
		if type(Value) == "table" and type(Previous) == "table" then
			Utils.QMerge(Value, Previous)
		elseif Previous == nil then
			To[Key] = Value
		end
	end
	return To
end

function Utils.Enqueue(List: {any}, Queue: {any}): ()
	for _, Item in List do TIns(Queue, Item) end
end

function Utils.BinInsert(List: {any}, Item: any, Key: string, Descending: boolean?): {any}
	local Low, High = 1, #List
	if Descending then
		while Low <= High do
			local Mid = MFlr((Low + High) / 2)
			if List[Mid][Key] >= Item[Key] then
				Low = Mid + 1
			else
				High = Mid - 1
			end
		end
	else
		while Low <= High do
			local Mid = MFlr((Low + High) / 2)
			if List[Mid][Key] <= Item[Key] then
				Low = Mid + 1
			else
				High = Mid - 1
			end
		end
	end
	TIns(List, Low, Item)
	return List
end

--/ Lighting

function Utils.IsNight(): boolean
	return Servos.Lighting.ClockTime >= 18 or Servos.Lighting.ClockTime <= 6
end
function Utils.IsDay(): boolean
	return Servos.Lighting.ClockTime <= 18 and Servos.Lighting.ClockTime >= 6
end

--/ Connections

function Utils.DisconnectAll(List: {RBXScriptConnection}): ()
	for _, Connection in List do
		if not (Connection and typeof(Connection) == "RBXScriptConnection") then continue end
		Connection:Disconnect()
	end
	table.clear(List)
end

--/ Modules

function Utils.React(State, Callback, Verifier: (any, any) -> boolean): any
	return setmetatable({}, {
		__index = State;
		__newindex = function(_, Key, Value)
			local Old = State[Key]
			if Old == Value then return end
			if Verifier and not Verifier(Old, Value) then return end
			State[Key] = Value
			Callback(Key, Value, Old)
		end
	})
end

return Utils
