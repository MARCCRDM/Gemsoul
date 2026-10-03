local fchecks = 0
local function fcheck(value, message)
	fchecks += 1
	assert(value, message)
end

-- Reports are cleaned before they're stored.
fcheck(Feedback.clean("Rant", "hello there") == nil, "An unknown kind was accepted")
fcheck(Feedback.clean("Bug", 42) == nil and Feedback.clean("Bug", "  hi  ") == nil, "Junk text was accepted")
local report = Feedback.clean("Bug", "   stuck after a duel   ")
fcheck(report and report.Kind == "Bug" and report.Text == "stuck after a duel", "Report not trimmed")
fcheck(#Feedback.clean("Idea", string.rep("x", 5000)).Text == Feedback.MaxText, "Long report not cut to size")

-- Errors are grouped by message and counted, most frequent first, capped.
local saved = { { Key = "Server:boom", Message = "boom", Side = "Server", Count = 3, Last = 10, Build = "a" } }
local merged = Feedback.mergeErrors(saved, {
	["Server:boom"] = { Message = "boom", Side = "Server", Count = 2, Last = 20, Build = "b" },
	["Client:oops"] = { Message = "oops", Side = "Client", Count = 9, Last = 15, Build = "b" },
}, 10)
fcheck(#merged == 2 and merged[1].Key == "Client:oops" and merged[2].Count == 5, "Errors not merged and ranked")
fcheck(merged[2].Last == 20 and merged[2].Build == "b", "Merged error not brought up to date")
local many = {}
for i = 1, 30 do
	many["Client:e" .. i] = { Message = "e" .. i, Side = "Client", Count = i, Last = i, Build = "b" }
end
local capped = Feedback.mergeErrors(nil, many, 10)
fcheck(#capped == 10 and capped[1].Count == 30 and capped[10].Count == 21, "Error list not capped to the most frequent")

print("PASS: " .. fchecks .. " feedback checks (report cleaning, error grouping, ranking and cap)")
