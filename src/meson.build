clicalculator_sources = [
  'main.vala',
  'Calcu_Logic.vala',
  'Collection.gs',
  'Default_Values.vala',
]

clicalculator_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  meson.get_compiler('c').find_library('m', required: false),

]

executable('clicalculator', clicalculator_sources,
  vala_args: '--target-glib=2.58',  dependencies: clicalculator_deps,
  install: true,
)
