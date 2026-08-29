package scratch_buffer

import "core:fmt"
import "core:math"

lerp_func :: proc(val1, val2, al: f32) -> (res: f32) {
	return val1 + (val2 - val1) * al
}

main :: proc(){
	res := lerp_func(10.0,100.0,0.1)
	res2 := math.lerp(10.0,100.0,0.1)
	for i :f64= 0; i < 2; i += 0.1 {
		fmt.println("i=", i)
		res = lerp_func(10.0,100.0,f32(0.1 + i))
		fmt.println("RES", res)
	}
}
