-- A deliberately unsafe transfer for the Postil preview demo.

local ledger = {}

local function transfer(first, second, amount)
  first:lock()
  second:lock()
  ledger[first.id] = ledger[first.id] - amount
  second:unlock()
  first:unlock()
end

return transfer
