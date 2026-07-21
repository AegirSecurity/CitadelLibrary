--!strict
--!native
--!optimize 2
--/ Citadel/Signal.luau (Client) (a. HeartOfIrons)
--/ Lightweight implementation of a Signal system
local Utils: {[string]: any}
local Clock = os.clock
local TRem, TClone, TUpk = table.remove, table.clone, table.unpack
local TClr, TPck = table.clear, table.pack
local COActive, COYield = coroutine.running, coroutine.yield
local TKDefer, TKDly, TKSpn = task.defer, task.delay, task.spawn

type Fn = (...any) -> ()
type Scope = {
	Priority: number?;
	Once: boolean?
}

export type Connection = {
	Connected: boolean; Once: boolean;
	Disconnect: (self: Connection) -> ();
	Reconnect: (self: Connection) -> ();
	Exec: (self: Connection, ...any) -> ();
	Signal: Signal; Func: Fn
}
export type Signal = {
	Destroyed: boolean; Deferred: boolean;
	Listeners: {Connection}; Queue: {thread};
	Fire: (self: Signal, ...any) -> ();
	Dispatch: (self: Signal, ...any) -> ();
	Connect: (self: Signal, Fn: Fn, Scope: Scope?) -> Connection;
	Wait: (self: Signal, Timeout: number?) -> (boolean, ...any);
	Wrap: (self: Signal, Native: RBXScriptSignal) -> Signal;
	GetConnections: (self: Signal) -> number;
	Destroy: (self: Signal) -> ();
	Bridge: RBXScriptConnection | nil
}

local Signal = {Version = "0.1.13:P"}
Signal.__index = Signal
local Connection = {}
Connection.__index = Connection

function Signal.Init(Utilities)
	assert(Utilities ~= nil, "Signal requires Aegir Utils package to work, pass Signal.Init(Utils)")
	Utils = Utilities
	Signal.Init = nil
end

local function Create(Owner: any, Fn: Fn, Once: boolean, Priority: number): Connection
	return setmetatable({Connected = true; Signal = Owner; Func = Fn; Once = Once; Priority = Priority}, Connection) :: any
end

function Connection.Disconnect(self: Connection): ()
	if not self.Connected then return end
	self.Connected = false
	local Listeners = self.Signal.Listeners
	for Index, Entry in Listeners do
		if Entry ~= self then continue end
		TRem(Listeners, Index)
		return
	end
end
function Connection.Reconnect(self: Connection): ()
	if self.Connected then return end
	if self.Signal.Destroyed then return end
	self.Connected = true
	Utils.BinInsert(self.Signal.Listeners, self, "Priority")
end
function Connection.Exec(self: Connection, ...: any): () self.Func(...) end

function Signal.New(Deferred: boolean?): Signal
	return setmetatable({Listeners = {}; Queue = {}; Deferred = Deferred == true; Destroyed = false}, Signal) :: any
end
function Signal.Wrap(Native: RBXScriptSignal): Signal
	local Wrapper = Signal.New()
	Wrapper.Bridge = Native:Connect(function(...) Wrapper:Fire(...) end)
	return Wrapper
end
function Signal.IsA(Object: any, Type: "Connection" | "Signal"): boolean
	if typeof(Object) ~= "table" then return false end
	local Meta = getmetatable(Object)
	if Type == "Connection" then return Meta == Connection
	elseif Type == "Signal" then return Meta == Signal end
	return false
end

function Signal.Connect(self: Signal, Func: Fn, Scope: Scope?): Connection
	assert(not self.Destroyed, "Signal is not implemented or is destroyed")
	Scope = Scope or {} :: Scope
	local Conn = Create(self, Func, Scope.Once or false, Scope.Priority or 0)
	Utils.BinInsert(self.Listeners, Conn, "Priority")
	return Conn
end
function Signal.Once(self: Signal, Func: Fn, Scope: Scope?): Connection
	local Merge: Scope = Scope or {}
	Merge.Once = true
	return self:Connect(Func, Merge)
end
function Signal.Dispatch(self: Signal, ...: any): ()
	local Listeners = self.Listeners
	local Count = #Listeners
	if Count == 0 then return end
	local Request = false
	for _, Conn in Listeners do
		if Conn.Once then
			Request = true
			break
		end
	end
	local Iteration = Request and TClone(Listeners) or Listeners
	for _, Connection: Connection in Iteration do
		if not Connection.Connected then continue end
		if Connection.Once then Connection:Disconnect() end
		local OK, Res = pcall(Connection.Func, ...)
		if not OK then
			TKSpn(error, `Signal Listener: {Res}`, 0)
		end
	end
end
function Signal.Fire(self: Signal, ...: any): ()
	assert(not self.Destroyed, "Signal is not implemented or is destroyed")
	if self.Deferred then
		local Args = TPck(...)
		TKDefer(function()
			if self.Destroyed then return end
			self:Dispatch(TUpk(Args, 1, Args.n))
		end)
		return
	end
	self:Dispatch(...)
end
function Signal.Wait(self: Signal, Timeout: number?): (boolean, ...any)
	assert(not self.Destroyed, "Signal is not implemented or is destroyed")
	local MThread = COActive()
	assert(MThread, "Signal cannot await in this context")
	local Conn: Connection | nil, Settled = nil, false
	local function Cleanup()
		local Queue = self.Queue
		for Index, Thread in Queue do
			if Thread == MThread then
				TRem(Queue, Index)
				break
			end
		end
	end
	Conn = self:Connect(function(...)
		if Settled then return end
		Settled = true
		Cleanup()
		TKSpn(Thread, true, ...)
	end, {Once = true, Priority = 1})
	TIns(self.Queue, Thread)
	if Timeout then
		TKDly(Timeout, function()
			if Settled then return end
			Settled = true
			Cleanup()
			if Conn then Conn:Disconnect() end
			TKSpn(Thread, false)
		end)
	end
	return COYield()
end
function Signal.GetConnections(self: Signal): number return #self.Listeners end
function Signal.DisconnectAll(self: Signal): ()
	for _, Connection in self.Listeners do
		Connection.Connected = false
	end
	TClr(self.Listeners)
end
function Signal.Destroy(self: Signal): ()
	if self.Destroyed then return end
	self.Destroyed = true
	if self.Bridge then
		self.Bridge:Disconnect()
		self.Bridge = nil
	end
	self:DisconnectAll()
	for _, Thread in self.Queue do
		TKSpn(Thread, false)
	end
	TClr(self.Waiting)
end

return Signal