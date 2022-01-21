using GLib.Math;

namespace DefaultValues {

    public static LinkedList <TokenData> get_default_tokens () {
        return new LinkedList <TokenData> .with_values (
            new TokenData () {
                key = "+",
                type = OPERATOR,
                priority = 1,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 1,
                    eval = (values) => values[0] + values[1]
                }
            },
            new TokenData () {
                key = "-",
                type = OPERATOR,
                priority = 1,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 1,
                    eval = (values) => values[0] - values[1]
                }
            },
            new TokenData () {
                key = "*",
                type = OPERATOR,
                priority = 2,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 1,
                    eval = (values) => values[0] * values[1]
                }
            },
            new TokenData () {
                key = "/",
                type = OPERATOR,
                priority = 2,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 1,
                    eval = (values) => values[0] / values[1]
                }
            },
            new TokenData () {
                key = "^",
                type = OPERATOR,
                priority = 3,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 1,
                    eval = (values) => pow (values [0], values [1])
                }
            },
            new TokenData () {
                key = "%",
                type = OPERATOR,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 0,
                    eval = (values) => values[0] / 100
                }
            },
            new TokenData () {
                key = "E",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values) => pow (10, values[0])
                }
            },
            new TokenData () {
                key = "!",
                type = OPERATOR,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 1,
                    arg_right = 0,
                    eval = (values) => faq (values[0])
                }
            },
            new TokenData () {
                key = "sin",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values, _, calc) => sin (calc.to_radian (values[0]))
                }
            },
            new TokenData () {
                key = "sinh",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values, _, calc) => sinh (calc.to_radian (values[0]))
                }
            },
            new TokenData () {
                key = "cos",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values, _, calc) => cos (calc.to_radian (values[0]))
                }
            },
            new TokenData () {
                key = "cosh",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values, _, calc) => cosh (calc.to_radian (values[0]))
                }
            },
            new TokenData () {
                key = "tan",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values, _, calc) => tan (calc.to_radian (values[0]))
                }
            },
            new TokenData () {
                key = "tanh",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values, _, calc) => tanh (calc.to_radian (values[0]))
                }
            },
            new TokenData () {
                key = "mean",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = -1,
                    min_arg_right = 1,
                    eval = mean
                }
            },
            new TokenData () {
                key = "median",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = -1,
                    min_arg_right = 1,
                    eval = median
                }
            },
            new TokenData () {
                key = "sum",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = -1,
                    min_arg_right = 2,
                    eval = sum
                }
            },
            new TokenData () {
                key = "root",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 2,
                    eval = (values) => pow (values[1], 1 / values[0])
                }
            },
            new TokenData () {
                key = "sqrt",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 1,
                    eval = (values) => sqrt (values [0])
                }
            },
            new TokenData () {
                key = "mod",
                type = FUNCTION_INTERN,
                priority = 4,
                eval_fun = fun_ () {
                    arg_left = 0,
                    arg_right = 2,
                    eval = (values) => mod (values[0], values[1])
                }
            },
            new TokenData () {
                key = "p",
                type = VARIABLE,
                has_value = true,
                value = Math.PI
            },
            new TokenData () {
                key = "pi",
                type = VARIABLE,
                has_value = true,
                value = Math.PI
            },
            new TokenData () {
                key = "e",
                type = VARIABLE,
                has_value = true,
                value = Math.E
            },
            new TokenData () {
                key = "(",
                type = OPENING_BRACKET,
            },
            new TokenData () {
                key = ")",
                type = CLOSING_BRACKET,
            },
            new TokenData () {
                key = ",",
                type = SEPARATOR,
            },
            new TokenData () {
                key = " ",
                type = SEPARATOR,
            }

        );
    }

}

