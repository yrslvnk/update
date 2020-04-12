--[[]
   Author: DonHomka
   Functions:
      - bool result, int id = createSphere(float x, float y, float z, float radius [, function callback(int id, bool enter)])
      - bool result = doesSphereExist(int id)
      - bool result = removeSphere(int id)
   E-mail: a.skinfy@gmail.com
   VK: http://vk.com/DonHomka
   TeleGramm: http://t.me/DonHomka
   Discord: DonHomka#2534
]]
local module = {}
module._VERSION = "1.0.0"
local tSphere = {}
local tSphereData = {}
local iLastSphere = 0

lua_thread.create(function ()
   while true do
      wait(0)
      if isPlayerPlaying(PLAYER_HANDLE) then
         local px, py, pz = getCharCoordinates(PLAYER_PED)
         for k, v in pairs(tSphere) do
            local bInSphere = getDistanceBetweenCoords3d(px, py, pz, v.x, v.y, v.z) <= v.r
            if bInSphere and module.onInSphere then
               module.onInSphere(k)
            end
            if bInSphere and tSphereData[k] == nil then
               if v.callback then
                  v.callback(k, true)
               elseif module.onEnterSphere then
                  module.onEnterSphere(k)
               end
               tSphereData[k] = true
            elseif not bInSphere and tSphereData[k] then
               if v.callback then
                  v.callback(k, false)
               elseif module.onExitSphere then
                  module.onExitSphere(k)
               end
               tSphereData[k] = nil
            end
         end
      end
   end
end)

function module.removeSphere(id)
   local bool = false
   if module.doesSphereExist(id) then
      tSphere[id] = nil
      bool = true
   end
   return bool
end

function module.createSphere(x, y, z, radius, callback)
   iLastSphere = iLastSphere + 1
   tSphere[iLastSphere] = {x = x, y = y, z = z, r = radius, callback = callback}
   return true, iLastSphere
end

function module.doesSphereExist(id)
   return tSphere[id] ~= nil
end

return module
