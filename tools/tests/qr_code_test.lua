dofile('tools/tests/mock.lua')
package.path='plugins/dev.leotrax3d.qr-code/?.lua;'..package.path
dofile('plugins/dev.leotrax3d.qr-code/qr_code.lua')
local opts={text='https://prusa3d.com',module_size=1.2,base=2,relief=0.6}
execute(opts)
assert(#objects==1)
local ok,m=require('qrencode').qrcode(opts.text,2)
assert(ok)
local boxes=world_boxes(objects[1])
local plate=boxes[1]
assert(math.abs(plate.z0)<1e-8 and math.abs(plate.z1-2)<1e-8)
local cells=0
for i=2,#boxes do
    local b=boxes[i]
    local tr=objects[1].translate
    b.x0=b.x0+tr.x; b.x1=b.x1+tr.x
    b.y0=b.y0+tr.y; b.y1=b.y1+tr.y
    b.z0=b.z0+tr.z; b.z1=b.z1+tr.z
    assert(b.x0>=plate.x0+4*1.2-1e-8 and b.x1<=plate.x1-4*1.2+1e-8)
    assert(b.y0>=plate.y0+4*1.2-1e-8 and b.y1<=plate.y1-4*1.2+1e-8)
    assert(math.abs(b.z0-1.95)<1e-8 and math.abs(b.z1-2.6)<1e-8)
    cells=cells+math.floor((b.x1-b.x0)/1.2+0.5)
end
local dark=0
for x=1,#m do for y=1,#m do if m[x][y]>0 then dark=dark+1 end end end
assert(cells==dark)
for _,text in ipairs({'',string.rep('x',121)}) do opts.text=text;assert(not pcall(execute,opts)) end
assert(#objects==1)
print('ok   QR plate geometry, quiet zone, module coverage and input validation')
