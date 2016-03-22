return { wrap_transposer = function(interface, address) 
  local r = { interface=interface, address=address }
  function r.get_slots_count(side) 
    return r.interface.get_slots_count(r.address, side)
  end
  function r.get_stack(side, slot) 
    return r.interface.get_stack(r.address, side, slot)
  end
  function r.get_istack(side, slot) 
    return r.interface.get_istack(r.address, side, slot)
  end
  function r.get_items_count(side, slot)
    return r.interface.get_items_count(r.address, side, slot)    
  end
  function r.transfer(source_side, sink_side, count, source_slot, sink_slot) 
    if count == nil then count = math.huge end 
    return r.interface.transfer(r.address, source_side, sink_side, count, source_slot, sink_slot)
  end  
  return r
end }
