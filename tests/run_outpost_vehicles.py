"""Run the server side of the mechs (no seats) with stand-in players and parts.

Uses Lune when installed, otherwise the bundled Luau and scene math doubles.
Neither runner substitutes for an in-engine multiplayer driving check.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
lune = shutil.which('lune')
if lune:
    subprocess.run([lune, 'run', str(ROOT / 'tests/outpost_vehicles_cases.luau'), str(ROOT)], check=True)
else:
    env = {'__file__': str(ROOT / 'tests/run_meadow_scene.py')}
    exec((ROOT / 'tests/run_meadow_scene.py').read_text().split('for name, path in')[0], env)
    source = env['source'] + r'''
local oldFrameIndex=cmt.__index
cmt.__index=function(a,k)
 if k=="LookVector" then return Vector3.new(-a.r[3],-a.r[6],-a.r[9]) end
 if k=="ToOrientation" then return function(x) return 0,math.atan2(x.r[3],x.r[9]),0 end end
 return oldFrameIndex(a,k)
end
local v2mt={}
local Vector2={new=function(x,y) return setmetatable({X=x,Y=y},v2mt) end}
v2mt.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y) end end
v2mt.__eq=function(a,b) return a.X==b.X and a.Y==b.Y end
vmt.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local function typeof(v) if type(v)=="table" and getmetatable(v)==vmt then return "Vector3" end return type(v) end
Vector2.zero=Vector2.new(0,0)
local R={Vector2=Vector2,Vector3=Vector3,CFrame=CFrame,Color3=Color3,Enum=Enum}
local modules={}
'''
    for path in ['src/shared/Outpost.luau', 'src/shared/MechPilot.luau', 'src/server/Systems/OutpostVehicles.luau', 'src/server/Systems/SeatExit.luau']:
        source += f'modules["{path}"]=function(env)\n'
        for name in ['game', 'script', 'require', 'Instance', 'Enum', 'CFrame', 'Vector2', 'Vector3', 'Color3', 'os', 'task', 'warn', 'print', 'typeof']:
            source += f'local {name}=env.{name} or {name}\n'
        source += (ROOT / path).read_text(encoding='utf-8') + '\nend\n'
    source += '''
local function load(path, env)
 return modules[path](env or {})
end
'''
    fixture = (ROOT / 'tests/outpost_vehicles_cases.luau').read_text(encoding='utf-8')
    checks = fixture[fixture.index('local checks = 0'):fixture.index('local function load(')]
    source += checks + fixture[fixture.index('local function signal()'):]
    with tempfile.TemporaryDirectory(prefix='gemsoul-server-drive-') as directory:
        path = Path(directory) / 'server.luau'
        path.write_text(source, encoding='utf-8')
        subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True)
