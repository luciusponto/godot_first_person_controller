class_name FpcDebugUtil
extends Object

## Print array values, considering even values (0-indexed) as labels, odd values
## as the actual values to be converted with str()
## Example input: ["pi", 3.14, "gravity", Vector3(0, -9.8, 0)]
## Example output: pi: 3.14; gravity: (0.000, -9.800, 0.000)
static func print_pairs(values: Array) -> void:
	var result := ""
	for i in range(0, len(values)):
		if i % 2 == 0:
			if i > 0:
				result = result + "; "
			result = result + values[i] + ": "
		else:
			result = result + str(values[i])
	print(result)

