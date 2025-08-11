--!strict

export type Entry = { userId: number, spent: number }

local TestStore = {}

local robuxSpentByUserId: {[number]: number} = {}

function TestStore.addSpend(userId: number, amount: number)
	if amount <= 0 then return end
	robuxSpentByUserId[userId] = (robuxSpentByUserId[userId] or 0) + amount
end

function TestStore.getRobuxSpent(userId: number): number
	return robuxSpentByUserId[userId] or 0
end

function TestStore.getTopSpenders(limit: number): {Entry}
	local list: {Entry} = {}
	for id, total in pairs(robuxSpentByUserId) do
		table.insert(list, { userId = id, spent = total })
	end
	table.sort(list, function(a, b)
		return a.spent > b.spent
	end)
	local result = {}
	for i = 1, math.min(limit, #list) do
		result[i] = list[i]
	end
	return result
end

return TestStore 