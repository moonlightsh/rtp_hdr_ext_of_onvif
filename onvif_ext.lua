
do
	local date = rawget(os,"date") -- use rawget to avoid disabled's os.__index

	if type(date) ~= "function" then
		-- 'os' has been disabled, use a dummy function for date
		date = function() return "" end
	end
	local function run_console()
		if console_open then return end
		console_open = true

		local w = TextWindow.new("Console")

		-- save original logger functions
		local orig_print = print

		-- define new logger functions that append text to the window
		function print(...)
			local arg = {...}
			local n = #arg
			w:append(date() .. " ")
			for i=1, n do
				if i > 1 then w:append("\t") end
				w:append(tostring(arg[i]))
			end
			w:append("\n")
		end

		-- when the window gets closed restore the original logger functions
		local function at_close()
			print = old_print

			console_open = false
		end

		w:set_atclose(at_close)
		print("Console opened")
	end   
	
	--run_console()
    --w = TextWindow.new("rtp onvif ext log")
	--w:append("rtp onvif ext log info\n")
	
	
	
	
	local onvif_ext_proto = Proto("onvif_ext", "Onvif Playback Header Extention")
	local msw_filed = ProtoField.uint32("onvif_ext.msw", "Timestamp, MSW", base.DEC)
	local lsw_filed = ProtoField.uint32("onvif_ext.lsw", "Timestamp, LSW", base.DEC)
	local ntp_filed = ProtoField.string("onvif_ext.ntp", "Timestamp, NPT calc", base.NONE)
	local flags_filed = ProtoField.uint8("onvif_ext.flags", "flags", base.HEX)
	local c_filed = ProtoField.uint8("onvif_ext.c", "C", base.DEC, null, 0x80)
	local e_filed = ProtoField.uint8("onvif_ext.e", "E", base.DEC, null, 0x40)
	local d_filed = ProtoField.uint8("onvif_ext.d", "D", base.DEC, null, 0x20)
	local t_filed = ProtoField.uint8("onvif_ext.t", "T", base.DEC, null, 0x10)
	local cseq_filed = ProtoField.uint8("onvif_ext.cseq", "cseq", base.DEC)
	onvif_ext_proto.fields = {
		msw_filed,
		lsw_filed,
		ntp_filed,
		flags_filed,
		c_filed,
		e_filed,
		d_filed,
		t_filed,
		cseq_filed
	}
	
	function onvif_ext_proto.dissector(buf, pinfo, tree)
		local offset = 0
		local msw = buf(offset, 4)
		offset = offset + 4
		local lsw = buf(offset, 4)
		offset = offset + 4
		local flags = buf(offset, 1)
		offset = offset + 1
		offset = offset + 2
		local cseq = buf(offset, 1)
		
		
		local ntp_sec = buf:range(0, 4)
		local ntp_nsec = buf:range(4, 4)
		
		local ntp_sec_of_tm = ntp_sec:uint() - ((70 * 365 + 17) * 24 * 60 * 60)
		
		local ntp_nsec_of_tm = ntp_nsec:uint64() * 232.83064365386962890625/1000000000
		pinfo.columns['info']:append(", Ntp=")
		pinfo.columns['info']:append(os.date("%c ",ntp_sec_of_tm)..tostring(ntp_nsec_of_tm));

		--print("ntp_sec.uint32():", os.date("%c ",ntp_sec_of_tm)..tostring(ntp_nsec_of_tm))
		
		local subtree = tree:add(onvif_ext_proto, buf(),"Onvif Playback Header Extention")
		subtree:add(msw_filed, msw)
		subtree:add(lsw_filed, lsw)
		subtree:add(ntp_filed, os.date("%c ",ntp_sec_of_tm)..tostring(ntp_nsec_of_tm))
		local msw_num = tonumber(msw)
		
		local flags_tree = subtree:add(flags_filed, flags)
		flags_tree:add(c_filed, flags)
		flags_tree:add(e_filed, flags)
		flags_tree:add(d_filed, flags)
		flags_tree:add(t_filed, flags)
		subtree:add(cseq_filed, cseq)
		
	end


	local rtp_diss_table = DissectorTable.get('rtp.hdr_ext')
	rtp_diss_table:add(0xabac, onvif_ext_proto)

end