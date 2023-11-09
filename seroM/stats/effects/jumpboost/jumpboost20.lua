function init()
  local bounds = mcontroller.boundBox()
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = 3}
  })
end

function update(dt)
  mcontroller.controlModifiers({
      airJumpModifier = 3
    })
end

function uninit()
  
end
