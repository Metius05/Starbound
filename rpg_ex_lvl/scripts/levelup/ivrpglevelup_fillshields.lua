oldLevelUpInit = init
function init()
	oldLevelUpInit()
	if status.statusProperty("blshielddata") then
		status.setStatusProperty("damageAbsorption",status.statusProperty("blshielddata").stats.capacity)
	end
end