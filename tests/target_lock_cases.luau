local checks = 0
local function check(value, message) checks += 1; assert(value, message) end
local function c(id, distance, facing, visible, allowed)
 return {Target=id, Distance=distance, Facing=facing or 1, Visible=visible ~= false, Allowed=allowed ~= false}
end
local s=Rules.new()
check(Rules.update(s,{c("far",20),c("near",8)},0,false)=="near","Nearest visible target not selected")
check(Rules.update(s,{c("far",2),c("near",8)},0.1,false)=="near","Lock jumped to closer entrant")
check(Rules.update(s,{c("near",8,0.8)},0.2,false)=="near","Normal tracking lost retained target")
check(Rules.update(s,{c("near",8,0.6)},0.3,true)==nil,"Deliberate turn did not release")
check(Rules.update(s,{c("new",4)},0.5,false)==nil,"Release immediately reacquired")
check(Rules.update(s,{c("new",4)},1,false)=="new","Release cooldown never expired")
check(Rules.update(s,{c("new",4,1,false),c("other",12)},1.1,false)=="other","Occluded lock retained")
s=Rules.new()
check(Rules.update(s,{c("off-axis",2,0.6),c("ahead",10)},0,false)=="ahead","Acquired outside forward cone")
s=Rules.new()
check(Rules.update(s,{c("friend",1,1,true,false),c("wall",2,1,false),c("far",61),c("valid",12)},0,false)=="valid","Eligibility, walls or range bypassed")
check(Rules.update(s,{c("valid",61)},0.1,false)==nil,"Out-of-range lock retained")
s=Rules.new()
check(Rules.update(s,{c("left",10,0.95),c("center",10,1)},0,false)=="center","Distance tie ignored central target")
check(Rules.update(s,{},0.1,false)==nil,"Removed target retained")
check(not Rules.valid(c("bad",0),Rules.AcquireDot),"Zero-distance target accepted")
print("PASS: "..checks.." soft target selection, visibility, hysteresis and turn-away checks")
