-- Encoder loaded only at invocation: the slicer's scan has no custom require.
info = {
    id = 'dev.leotrax3d.qr-code', type = 'project.plugin',
    title = 'QR Code', menu = 'Generators/QR Code',
    params = {
        {name='text', label='Text / URL (max 120 bytes)', type='string', default='https://prusa3d.com'},
        {name='module_size', label='Module size [mm]', type='float', default=1.2},
        {name='base', label='Plate thickness [mm]', type='float', default=2},
        {name='relief', label='Raised code height [mm]', type='float', default=0.6}
    }
}

function execute(opts)
    assert(type(opts.text)=='string' and #opts.text>0 and #opts.text<=120,
        'Enter 1–120 bytes of text (UTF-8 characters may use several bytes).')
    local function dimension(name, lo, hi)
        local v=opts[name]
        assert(type(v)=='number' and v==v and v>=lo and v<=hi,
            name .. ' must be between ' .. lo .. ' and ' .. hi .. ' mm')
        return v
    end
    local pitch=dimension('module_size',0.8,5)
    local base=dimension('base',0.4,10)
    local relief=dimension('relief',0.2,3)
    local ok, matrix=require('qrencode').qrcode(opts.text,2)
    assert(ok, tostring(matrix))
    local n=#matrix
    local size=(n+8)*pitch -- mandatory four-module quiet zone on every side
    local plate=api.make_cube(size,size,base)
    local b=plate:bounds()
    local origin={x=-size/2-b.min_x,y=-size/2-b.min_y,z=-b.min_z}
    local volumes={}
    -- Merge horizontal dark runs to reduce the number of slicer volumes.
    for y=1,n do
        local x=1
        while x<=n do
            if matrix[x][y]>0 then
                local first=x
                repeat x=x+1 until x>n or matrix[x][y]<=0
                local mesh=api.make_cube((x-first)*pitch,pitch,relief+0.05)
                local bounds=mesh:bounds()
                volumes[#volumes+1]={mesh=mesh,type=VolumeType.Solid,translate={
                    x=-size/2+(first+3)*pitch-bounds.min_x-origin.x,
                    y=-size/2+(n-y+4)*pitch-bounds.min_y-origin.y,
                    z=base-0.05-bounds.min_z-origin.z}}
            else x=x+1 end
        end
    end
    api.project:add_object{mesh=plate,translate=origin,other_volumes=volumes}
end
