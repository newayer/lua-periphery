--
-- lua-periphery by vsergeev
-- https://github.com/vsergeev/lua-periphery
-- License: MIT
--

require('test')
local periphery = require('periphery')
local GPIO = periphery.GPIO

--------------------------------------------------------------------------------

local path = nil
local line_input = nil
local line_output = nil

--------------------------------------------------------------------------------

function test_arguments()
    local gpio = nil

    ptest()

    -- Invalid open types
    passert_periphery_error("invalid open types", function () gpio = GPIO(1, 1, "in") end, "GPIO_ERROR_ARG")
    passert_periphery_error("invalid open types", function () gpio = GPIO{path=1, line=1, direction="in"} end, "GPIO_ERROR_ARG")
    passert_periphery_error("invalid open types", function () gpio = GPIO("abc", {}, "in") end, "GPIO_ERROR_ARG")
    passert_periphery_error("invalid open types", function () gpio = GPIO{path="abc", line={}, direction="in"} end, "GPIO_ERROR_ARG")
    passert_periphery_error("invalid open types", function () gpio = GPIO("abc", 1, 1) end, "GPIO_ERROR_ARG")
    passert_periphery_error("invalid open types", function () gpio = GPIO{path="abc", line=1, direction=1} end, "GPIO_ERROR_ARG")
    -- Invalid direction
    passert_periphery_error("invalid direction", function () gpio = GPIO("abc", 1, "blah") end, "GPIO_ERROR_ARG")
    passert_periphery_error("invalid direction", function () gpio = GPIO{path="abc", line=1, direction="blah"} end, "GPIO_ERROR_ARG")
end

function test_open_config_close()
    local gpio = nil

    ptest()

    -- Open non-existent GPIO (export should fail with EINVAL)
    passert_periphery_error("non-existent GPIO", function () gpio = GPIO(path, 9999, "in") end, "GPIO_ERROR_OPEN", 22)

    -- Open legitimate GPIO
    passert_periphery_success("real GPIO", function () gpio = GPIO(path, line_output, "in") end)

    -- Check properties
    passert("property line", gpio.line == line_output)
    passert("direction is in", gpio.direction == "in")
    passert("fd >= 0", gpio.fd >= 0)
    passert("chip_fd >= 0", gpio.chip_fd >= 0)

    -- Set invalid direction
    passert_periphery_error("set invalid direction", function () gpio.direction = "blah" end, "GPIO_ERROR_ARG")
    -- Set invalid edge
    passert_periphery_error("set invalid edge", function () gpio.edge = "blah" end, "GPIO_ERROR_ARG")

    -- Set direction out, check direction out, check value low
    passert_periphery_success("set direction out", function () gpio.direction = "out" end)
    passert("direction is out", gpio.direction == "out")
    passert("value is low", gpio:read() == false)
    -- Set direction low, check direction out, check value low
    passert_periphery_success("set direction low", function () gpio.direction = "low" end)
    passert("direction is out", gpio.direction == "out")
    passert("Value is low", gpio:read() == false)
    -- Set direction high, check direction out, check value high
    passert_periphery_success("set direction high", function () gpio.direction = "high" end)
    passert("direction is in", gpio.direction == "out")
    passert("value is high", gpio:read() == true)
    -- Attempt to set interrupt edge on output GPIO
    passert_periphery_error("set interrupt edge on output GPIO", function () gpio.edge = "rising" end, "GPIO_ERROR_INVALID_OPERATION")
    -- Attempt to read event on output GPIO
    passert_periphery_error("read event on output GPIO", function () gpio:read_event() end, "GPIO_ERROR_INVALID_OPERATION")

    -- Set direction in, check direction in
    passert_periphery_success("set direction", function () gpio.direction = "in" end)
    passert("direction is in", gpio.direction == "in")

    -- Set edge none, check edge none
    passert_periphery_success("set edge none", function () gpio.edge = "none" end)
    passert("edge is none", gpio.edge == "none")
    -- Set edge rising, check edge rising
    passert_periphery_success("set edge rising", function () gpio.edge = "rising" end)
    passert("edge is rising", gpio.edge == "rising")
    -- Set edge falling, check edge falling
    passert_periphery_success("set edge falling", function () gpio.edge = "falling" end)
    passert("edge is falling", gpio.edge == "falling")
    -- Set edge both, check edge both
    passert_periphery_success("set edge both", function () gpio.edge = "both" end)
    passert("edge is both", gpio.edge == "both")
    -- Set edge none, check edge none
    passert_periphery_success("set edge none", function () gpio.edge = "none" end)
    passert("edge is none", gpio.edge == "none")

    -- Close gpio
    passert_periphery_success("close gpio", function () gpio:close() end)

    -- Open with table arguments
    passert_periphery_success("real GPIO", function () gpio = GPIO{path=path, line=line_output, direction="in"} end)
    passert("property line", gpio.line == line_output)
    passert("direction is in", gpio.direction == "in")
    passert("fd >= 0", gpio.fd >= 0)
    passert("chip_fd >= 0", gpio.chip_fd >= 0)
    passert_periphery_success("set direction out", function () gpio.direction = "out" end)
    passert_periphery_success("close gpio", function () gpio:close() end)
end

function test_loopback()
    local gpio_in = nil
    local gpio_out = nil

    ptest()

    -- Open in and out lines
    passert_periphery_success("open gpio in", function () gpio_in = GPIO(path, line_input, "in") end)
    passert_periphery_success("open gpio out", function () gpio_out = GPIO(path, line_output, "out") end)

    -- Drive out low, check in low
    print("Drive out low, check in low")
    passert_periphery_success("write gpio out low", function () gpio_out:write(false) end)
    passert("value is false", gpio_in:read() == false)

    -- Drive out high, check in high
    print("Drive out high, check in high")
    passert_periphery_success("write gpio out high", function () gpio_out:write(true) end)
    passert("value is true", gpio_in:read() == true)

    -- Check poll falling 1 -> 0 interrupt
    print("Check poll falling 1 -> 0 interrupt")
    passert_periphery_success("set gpio in edge falling", function () gpio_in.edge = "falling" end)
    passert_periphery_success("write gpio out low", function () gpio_out:write(false) end)
    passert("gpio in polled 1", gpio_in:poll(1000) == true)
    passert("value is low", gpio_in:read() == false)
    local event = gpio_in:read_event()
    passert("event edge is falling", event.edge == "falling")
    passert("event timestamp is non-zero", event.timestamp ~= 0)

    -- Check poll rising 0 -> 1 interrupt
    print("Check poll rising 0 -> 1 interrupt")
    passert_periphery_success("set gpio in edge rising", function () gpio_in.edge = "rising" end)
    passert_periphery_success("write gpio out high", function () gpio_out:write(true) end)
    passert("gpio in polled 1", gpio_in:poll(1000) == true)
    passert("value is high", gpio_in:read() == true)
    local event = gpio_in:read_event()
    passert("event edge is rising", event.edge == "rising")
    passert("event timestamp is non-zero", event.timestamp ~= 0)

    -- Set edge both
    passert_periphery_success("set gpio in edge both", function () gpio_in.edge = "both" end)

    -- Check poll falling 1 -> 0 interrupt
    print("Check poll falling 1 -> 0 interrupt")
    passert_periphery_success("write gpio out low", function () gpio_out:write(false) end)
    passert("gpio in polled 1", gpio_in:poll(1000) == true)
    passert("value is low", gpio_in:read() == false)
    local event = gpio_in:read_event()
    passert("event edge is falling", event.edge == "falling")
    passert("event timestamp is non-zero", event.timestamp ~= 0)

    -- Check poll rising 0 -> 1 interrupt
    print("Check poll rising 0 -> 1 interrupt")
    passert_periphery_success("write gpio out high", function () gpio_out:write(true) end)
    passert("gpio in polled 1", gpio_in:poll(1000) == true)
    passert("value is high", gpio_in:read() == true)
    local event = gpio_in:read_event()
    passert("event edge is rising", event.edge == "rising")
    passert("event timestamp is non-zero", event.timestamp ~= 0)

    -- Check poll timeout
    passert("poll timed out", gpio_in:poll(1000) == false)

    -- Test poll_multiple() API with one GPIO

    -- Check poll falling 1 -> 0 interrupt
    print("Check poll falling 1 -> 0 interrupt with poll_multiple()")
    passert_periphery_success("write gpio out low", function () gpio_out:write(false) end)
    local gpios_ready = GPIO.poll_multiple({gpio_in}, 1000)
    passert("gpios_ready length is 1", #gpios_ready == 1)
    passert("gpios_ready[1] is gpio in", gpios_ready[1] == gpio_in)
    passert("value is low", gpio_in:read() == false)
    local event = gpio_in:read_event()
    passert("event edge is falling", event.edge == "falling")
    passert("event timestamp is non-zero", event.timestamp ~= 0)

    -- Check poll rising 0 -> 1 interrupt
    print("Check poll rising 0 -> 1 interrupt with poll_multiple()")
    passert_periphery_success("write gpio out high", function () gpio_out:write(true) end)
    local gpios_ready = GPIO.poll_multiple({gpio_in}, 1000)
    passert("gpios_ready length is 1", #gpios_ready == 1)
    passert("gpios_ready[1] is gpio_in", gpios_ready[1] == gpio_in)
    passert("value is high", gpio_in:read() == true)
    local event = gpio_in:read_event()
    passert("event edge is rising", event.edge == "rising")
    passert("event timestamp is non-zero", event.timestamp ~= 0)

    -- Check poll timeout
    local gpios_ready = GPIO.poll_multiple({gpio_in}, 1000)
    passert("poll_multiple timed out", #gpios_ready == 0)

    passert_periphery_success("close gpio in", function () gpio_in:close() end)
    passert_periphery_success("close gpio out", function () gpio_out:close() end)
end

function test_interactive()
    local gpio = nil

    ptest()

    passert_periphery_success("gpio out open", function () gpio = GPIO(path, line_output, "out") end)

    print("Starting interactive test. Get out your multimeter, buddy!")
    print("Press enter to continue...")
    io.read()

    -- Check tostring
    io.write(string.format("GPIO description: %s\n", gpio:__tostring()))
    print("GPIO description looks OK? y/n")
    passert("interactive success", io.read() == "y")

    -- Drive GPIO out low
    passert_periphery_success("gpio out low", function () gpio:write(false) end)
    print("GPIO out is low? y/n")
    passert("interactive success", io.read() == "y")

    -- Drive GPIO out high
    passert_periphery_success("gpio out high", function () gpio:write(true) end)
    print("GPIO out is high? y/n")
    passert("interactive success", io.read() == "y")

    -- Drive GPIO out low
    passert_periphery_success("gpio out low", function () gpio:write(false) end)
    print("GPIO out is low? y/n")
    passert("interactive success", io.read() == "y")

    passert_periphery_success("close gpio", function () gpio:close() end)
end

if #arg < 3 then
    io.stderr:write(string.format("Usage: lua %s <GPIO chip device> <GPIO #1> <GPIO #2>\n\n", arg[0]))
    io.stderr:write("[1/4] Argument test: No requirements.\n")
    io.stderr:write("[2/4] Open/close test: GPIO #2 should be real.\n")
    io.stderr:write("[3/4] Loopback test: GPIOs #1 and #2 should be connected with a wire.\n")
    io.stderr:write("[4/4] Interactive test: GPIO #2 should be observed with a multimeter.\n\n")
    io.stderr:write("Hint: for Raspberry Pi 3,\n")
    io.stderr:write("Use GPIO 17 (header pin 11) and GPIO 27 (header pin 13),\n")
    io.stderr:write("connect a loopback between them, and run this test with:\n")
    io.stderr:write(string.format("    lua %s /dev/gpiochip0 17 27\n\n", arg[0]))
    os.exit(1)
end

path = arg[1]
line_input = tonumber(arg[2])
line_output = tonumber(arg[3])

test_arguments()
pokay("Arguments test passed.")
test_open_config_close()
pokay("Open/close test passed.")
test_loopback()
pokay("Loopback test passed.")
test_interactive()
pokay("Interactive test passed.")

pokay("All tests passed!")

