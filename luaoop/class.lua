--class.lua

local ssub      = string.sub
local sformat   = string.format
local dgetinfo  = debug.getinfo

--类模板
local class_tpls = _G.class_tpls or {}

local function deep_copy(src, dst)
	local ndst = dst or {}
	for key, value in pairs(src or {}) do
		if is_class(value) then
			ndst[key] = value()
		elseif (type(value) == "table") then
			ndst[key] = deep_copy(value)
		else
			ndst[key] = value
		end
	end
	return ndst
end

local function object_init(class, object, ...)
	if class.__super then
		object_init(class.__super, object, ...)
	end
	if type(class.__init) == "function" then
		class.__init(object, ...)
	end
	for _, mixin in ipairs(class.__mixins) do
		if type(mixin.__init) == "function" then
			mixin.__init(object, ...)
		end
	end
	return object
end

local function object_release(class, object, ...)
	for _, mixin in ipairs(class.__mixins) do
		if type(mixin.__release) == "function" then
			mixin.__release(object, ...)
		end
	end
	if type(class.__release) == "function" then
		class.__release(object, ...)
	end
	if class.__super then
		object_release(class.__super, object, ...)
	end
end

local function object_props(class, object)
	if class.__super then
		object_props(class.__super, object)
	end
	local props = deep_copy(class.__props)
	for name, param in pairs(props) do
		object[name] = param[1]
	end
end

local function object_tostring(object)
	if type(object.tostring) == "function" then
		return object:tostring()
	end
	return sformat("class:%s(%s)", object.__moudle, object.__addr)
end

local function object_constructor(class, ...)
	local obj = {}
	object_props(class, obj)
	obj.__addr = ssub(tostring(obj), 7)
	local object = setmetatable(obj, class.__vtbl)
	object_init(class, object, ...)
	return object
end

local function object_super(obj)
	return obj.__super
end

local function object_address(obj)
	return obj.__addr
end

local function mt_class_new(class, ...)
	if rawget(class, "__singleton") then
		local inst_obj = rawget(class, "__inst")
		if not inst_obj then
			inst_obj = object_constructor(class, ...)
			--定义单例方法
			local inst_func = function()
				return inst_obj
			end
			rawset(class, "__inst", inst_obj)
			rawset(class, "inst", inst_func)
		end
		return inst_obj
	else
		return object_constructor(class, ...)
	end
end

local function mt_class_index(class, field)
	return class.__vtbl[field]
end

local function mt_class_newindex(class, field, value)
	class.__vtbl[field] = value
end

local function mt_object_release(obj)
	object_release(obj.__class, obj)
end

local classMT = {
	__call = mt_class_new,
	__index = mt_class_index,
	__newindex = mt_class_newindex
}

local function class_constructor(class, super, ...)
	local info = dgetinfo(2, "S")
	local moudle = info.short_src
	local class_tpl = class_tpls[moudle]
	if not class_tpl then
		local vtbl = {
			__class = class,
			__super = super,
			__moudle = moudle,
			__tostring = object_tostring,
			address = object_address,
			super = object_super,
		}
		vtbl.__index = vtbl
		vtbl.__gc = mt_object_release
		if super then
			setmetatable(vtbl, {__index = super})
		end
		class.__vtbl = vtbl
		class.__super = super
		class.__props = {}
		class.__mixins = {}
		class_tpl = setmetatable(class, classMT)
		implemented(class, { ... })
		class_tpls[moudle] = class_tpl
	end
	return class_tpl
end

function class(super, ...)
	return class_constructor({}, super, ...)
end

function singleton(super, ...)
	return class_constructor({__singleton = true}, super, ...)
end

function super(value)
	return value.__super
end

function is_class(class)
	return classMT == getmetatable(class)
end
