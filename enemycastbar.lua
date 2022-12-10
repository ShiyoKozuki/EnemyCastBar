addon.name      = 'EnemyCastBar';
addon.author    = 'Shiyo';
addon.version   = '2.1.0.0';
addon.desc      = 'Shows enemy cast bars';
addon.link      = 'https://ashitaxi.com/';

require('common');
require ('shiyolibs')
local fonts = require('fonts');
local settings = require('settings');
local textDuration = 0
local monsterIndex
local tpId
local tpString
local monsterName
local spellId

local default_settings = T{
	font = T{
        visible = true,
        font_family = 'Arial',
        font_height = 18,
        color = 0xFFFFFFFF,
        position_x = 1,
        position_y = 1,
		background = T{
			visible = true,
			color = 0x80000000,
		}
    }
};

local function CheckString(string)
    if (string ~= nil) then
        textDuration = os.time() + 5 -- supposed to stop showing after 5s of TP move being used
    end
end

local enemycastbar = T{
	settings = settings.load(default_settings)
};


ashita.events.register('load', 'load_cb', function ()
    enemycastbar.font = fonts.new(enemycastbar.settings.font);
end);


ashita.events.register('packet_in', 'packet_in_cb', function (e)
    local myTarget = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive())
    -- Packet: Action
    if (e.id == 0x028) then
        local actionPacket = ParseActionPacket(e);
        local category = ashita.bits.unpack_be(e.data:totable(), 0, 82, 4);
        if (actionPacket.Type  == 7) and IsMonster(actionPacket.UserIndex) and (myTarget == actionPacket.UserIndex) then -- Mobskill Start
            local monsterId = struct.unpack('L', e.data, 0x05 + 0x01);
            monsterIndex = bit.band(monsterId, 0x7FF);
            tpId = ashita.bits.unpack_be(e.data:totable(), 0, 213, 17);
            if (AshitaCore:GetResourceManager():GetString('monsters.abilities', tpId - 256) ~= nil) then
                tpString = 'using ' .. AshitaCore:GetResourceManager():GetString('monsters.abilities', tpId - 256) 
            end
            monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
            textDuration = 0
            CheckString(tpString)
        elseif (actionPacket.Type == 35) and IsMonster(actionPacket.UserIndex) and (myTarget == actionPacket.UserIndex) then -- Mob Skill interrupted Interrupted
            -- print('Enemy mob ability interrupted!!');
            textDuration = 0
            tpId = 0
            tpString = 'TP move was interrupted!'
            monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
            textDuration = 0
            CheckString(tpString)
        end
        if (actionPacket.Type == 8) and IsMonster(actionPacket.UserIndex) and (myTarget == actionPacket.UserIndex) then  -- Magic start
            local monsterId = struct.unpack('L', e.data, 0x05 + 0x01);
            monsterIndex = bit.band(monsterId, 0x7FF);
            spellId = actionPacket.Targets[1].Actions[1].Param
            local spellResource = AshitaCore:GetResourceManager():GetSpellById(spellId);
            if spellResource then
                -- print(string.format('Enemy started casting %s.', spellResource.Name[1]));
                if (spellResource.Name[1] ~= nil) then
                    spellString = 'casting ' .. spellResource.Name[1]
                end
                monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
                textDuration = 0
                -- print(string.format('monsterName: %s', monsterName));
                CheckString(spellString)
            elseif (actionPacket.Type == 31) and IsMonster(actionPacket.UserIndex) and (myTarget == actionPacket.UserIndex) then -- Magic Interrupted
                -- print('Enemy spell interrupted!!');
                textDuration = 0
                spellString = 'spell was interrupted!'
                monsterName = AshitaCore:GetMemoryManager():GetEntity():GetName(monsterIndex);
                textDuration = 0
                CheckString(spellString)
            end
        end
    end
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    if (os.time() > textDuration ) then
        -- Hide text, reset variables to nil
        enemycastbar.font.visible = false;
        monsterIndex = nil
        tpId = nil
        tpString = nil
        monsterName = nil
        spellId = nil
        return;
    end
	if monsterName then
        if tpString and (tpId ~= nil) then
            enemycastbar.font.text = ('%s %s!'):fmt(monsterName, tpString);
            enemycastbar.settings.font.position_x = enemycastbar.font:GetPositionX();
            enemycastbar.settings.font.position_y = enemycastbar.font:GetPositionY();
            enemycastbar.font.visible = true;
        elseif monsterName and (spellId ~= nil) then
            enemycastbar.font.text = ('%s %s!'):fmt(monsterName, spellString);
            enemycastbar.settings.font.position_x = enemycastbar.font:GetPositionX();
            enemycastbar.settings.font.position_y = enemycastbar.font:GetPositionY();
            enemycastbar.font.visible = true;
        else
            enemycastbar.font.visible = false;
            return;
        end
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    if (enemycastbar.font ~= nil) then
        enemycastbar.font:destroy();
    end
settings.save();
end);

