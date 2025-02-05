--[[
   Factorio item crafting calculator
]]

function item_make_id(items, item_name)

  local item_names_to_ids          = items.names_to_ids
  local item_names                 = items.names
  local item_types                 = items.types
  local item_ingredient_in_recipes = items.ingredient_in_recipes
  local item_product_in_recipes    = items.product_in_recipes

  assert(item_names_to_ids[item_name] == nil)

  local item_id = #item_names+1
  item_names_to_ids[item_name]        = item_id
  item_names[item_id]                 = item_name
  item_types[item_id]                 = 0
  item_ingredient_in_recipes[item_id] = {}
  item_product_in_recipes[item_id]    = {}

  return item_id
end

function item_add_type(items, item_id, item_type)

  local item_types              = items.types
  local item_type_names_to_vals = items.type_names_to_vals

  local item_type_val = item_type_names_to_vals[item_type]

  assert(item_type_val ~= nil)
  assert((item_types[item_id] % (2*item_type_val)) < item_type_val)

  item_types[item_id] = item_types[item_id] + item_type_val
end

function recipe_make_id(recipes, recipe_name)

  local recipe_names_to_ids       = recipes.names_to_ids
  local recipe_names              = recipes.names
  local recipe_times              = recipes.times
  local recipe_ingredient_ids     = recipes.ingredient_ids
  local recipe_ingredient_amounts = recipes.ingredient_amounts
  local recipe_product_ids        = recipes.product_ids
  local recipe_product_amounts    = recipes.product_amounts
  local recipe_allowed            = recipes.allowed

  local recipe_id = #recipe_names+1
  recipe_names_to_ids[recipe_name]     = recipe_id
  recipe_names[recipe_id]              = recipe_name
  recipe_times[recipe_id]              = 0.5
  recipe_ingredient_ids[recipe_id]     = {}
  recipe_ingredient_amounts[recipe_id] = {}
  recipe_product_ids[recipe_id]        = {}
  recipe_product_amounts[recipe_id]    = {}
  recipe_allowed[recipe_id]            = true

  return recipe_id
end

function recipe_add_ingredient(recipes, items, recipe_id, item_name, item_amount, item_type)

  local item_names_to_ids          = items.names_to_ids
  local item_types                 = items.types
  local item_ingredient_in_recipes = items.ingredient_in_recipes
  local item_type_names_to_vals    = items.type_names_to_vals

  local recipe_ingredient_ids     = recipes.ingredient_ids[recipe_id]
  local recipe_ingredient_amounts = recipes.ingredient_amounts[recipe_id]

  -- get existing item id or make new one
  local item_id = item_names_to_ids[item_name] or item_make_id(items, item_name)

  -- handle item fields
  local item_ingredient = item_ingredient_in_recipes[item_id]
  item_ingredient[#item_ingredient+1] = recipe_id
  if item_type then
    local item_type_val = item_type_names_to_vals[item_type]
    assert(item_type_val ~= nil)
    if (item_types[item_id] % (2*item_type_val) < item_type_val) then
      item_types[item_id] = item_types[item_id] + item_type_val
    end
  end

  -- handle recipe fields
  recipe_ingredient_ids[#recipe_ingredient_ids+1]         = item_id
  recipe_ingredient_amounts[#recipe_ingredient_amounts+1] = item_amount

end

function recipe_add_product(recipes, items, recipe_id, item_name, item_amount, item_type)

  local item_names_to_ids       = items.names_to_ids
  local item_types              = items.types
  local item_product_in_recipes = items.product_in_recipes
  local item_type_names_to_vals = items.type_names_to_vals

  local recipe_product_ids     = recipes.product_ids[recipe_id]
  local recipe_product_amounts = recipes.product_amounts[recipe_id]

  -- get existing item id or make new one
  local item_id = item_names_to_ids[item_name] or item_make_id(items, item_name)

  -- handle item fields
  local item_product = item_product_in_recipes[item_id]
  item_product[#item_product+1] = recipe_id
  if item_type then
    local item_type_val = item_type_names_to_vals[item_type]
    assert(item_type_val ~= nil)
    if (item_types[item_id] % (2*item_type_val) < item_type_val) then
      item_types[item_id] = item_types[item_id] + item_type_val
    end
  end

  -- handle recipe fields
  recipe_product_ids[#recipe_product_ids+1]         = item_id
  recipe_product_amounts[#recipe_product_amounts+1] = item_amount

end

function parse_recipes(recipes, items)
  local filename = "data.lua"
  print(string.format("parsing recipes from %s", filename))

  local factorio_data = dofile(filename)
  assert(factorio_data ~= nil)

  -- for k,v in pairs(factorio_data) do
  --   print(k,v)
  -- end

  local item_names_to_ids       = items.names_to_ids
  local item_types              = items.types

  local recipe_times               = recipes.times
  local recipe_allowed             = recipes.allowed
  local recipe_disallowed_patterns = recipes.disallowed_patterns

  -- fill resources
  assert(factorio_data.resource ~= nil)
  for item_name,item in pairs(factorio_data.resource) do
    local item_id = item_names_to_ids[item_name]
    if item_id == nil then
      item_id = item_make_id(items, item_name)
    end
    item_add_type(items, item_id, item.type)
  end

  -- fill fluids
  assert(factorio_data.fluid ~= nil)
  for item_name,item in pairs(factorio_data.fluid) do
    local item_id = item_names_to_ids[item_name]
    if item_id == nil then
      item_id = item_make_id(items, item_name)
    end
    item_add_type(items, item_id, item.type)
  end

  -- fill items
  assert(factorio_data.item ~= nil)
  for item_name,item in pairs(factorio_data.item) do
    local item_id = item_names_to_ids[item_name]
    if item_id == nil then
      item_id = item_make_id(items, item_name)
    end
    item_add_type(items, item_id, item.type)
  end

  -- fill recipes
  assert(factorio_data.recipe ~= nil)
  for recipe_name,recipe in pairs(factorio_data.recipe) do

    local recipe_id = recipe_make_id(recipes, recipe_name)

    -- check if allowed
    recipe_allowed[recipe_id] = true
    for p=1,#recipe_disallowed_patterns do
      local pattern = recipe_disallowed_patterns[p]
      if string.find(recipe_name, pattern) ~= nil then
        recipe_allowed[recipe_id] = false
      end
    end

     -- time in seconds, called energy_required in factorio data, 0.5 if undefined
    local recipe_info = recipe.normal or recipe
    recipe_times[recipe_id] = recipe_info.energy_required or 0.5

    -- handle ingredients
    if recipe_info.ingredients then
      for _,item in pairs(recipe_info.ingredients) do

        if #item > 0 then
          assert(#item == 2)
          recipe_add_ingredient(recipes, items, recipe_id, item[1], item[2])
        else
          assert(item.name)
          assert(item.amount > 0)
          recipe_add_ingredient(recipes, items, recipe_id, item.name, item.amount, item.type)
        end
      end
    end

    -- handle products
    if recipe_info.results then
      for _,item in pairs(recipe_info.results) do

        if #item > 0 then
          assert(#item == 2)
          recipe_add_product(recipes, items, recipe_id, item[1], item[2])
        else
          assert(item.name)
          assert(item.amount > 0)
          local amount = item.amount * (item.probability or 1) -- uranium-ore has probability
          recipe_add_product(recipes, items, recipe_id, item.name, amount, item.type)
        end
      end
    else
      if not recipe_info.result then
        print("product", recipes.names[recipe_id], recipe_info.result, recipe_info.result_count or 1)
      end
      assert(recipe_info.result)
      recipe_add_product(recipes, items, recipe_id, recipe_info.result, recipe_info.result_count or 1)
    end

  end

  -- print("parse recipes end")
end

function print_recipes(recipes, items)
  print("print recipes")
  local item_names            = items.names
  local item_ingredient_in_recipes = items.ingredient_in_recipes
  local item_product_in_recipes    = items.product_in_recipes

  assert(#item_names == #item_ingredient_in_recipes)
  assert(#item_names == #item_product_in_recipes)

  local recipe_names              = recipes.names
  local recipe_times              = recipes.times
  local recipe_ingredient_ids     = recipes.ingredient_ids
  local recipe_ingredient_amounts = recipes.ingredient_amounts
  local recipe_product_ids        = recipes.product_ids
  local recipe_product_amounts    = recipes.product_amounts

  assert(#recipe_names == #recipe_times)
  assert(#recipe_names == #recipe_ingredient_ids)
  assert(#recipe_names == #recipe_ingredient_amounts)
  assert(#recipe_names == #recipe_product_ids)
  assert(#recipe_names == #recipe_product_amounts)

  print(#recipe_names)

  for recipe_id=1,#recipe_names do
    local name               = recipe_names[recipe_id]
    local time               = recipe_times[recipe_id]
    local ingredient_ids     = recipe_ingredient_ids[recipe_id];
    local ingredient_amounts = recipe_ingredient_amounts[recipe_id];
    local product_ids        = recipe_product_ids[recipe_id];
    local product_amounts    = recipe_product_amounts[recipe_id];

    print(string.format("recipe '%s' %gs", name, time))

    assert(#ingredient_ids == #ingredient_amounts)
    for ingredient_i=1,#ingredient_ids do
      print(string.format("    ingredient '%s' x%u", item_names[ingredient_ids[ingredient_i]], ingredient_amounts[ingredient_i]))
    end

    assert(#product_ids == #product_amounts)
    for product_i=1,#product_ids do
      print(string.format("    product '%s' x%u", item_names[product_ids[product_i]], product_amounts[product_i]))
    end

  end

  print("print recipes end")
end

function print_recipe_and_ingredients(recipes, items, recipe_id, rate, print_prefix)
  print_prefix = print_prefix or ""

  -- print(string.format("%s '%s' recipe_id x%g/s", print_prefix, recipe_id, rate))

  local recipe_name               = recipes.names[recipe_id]

  local item_product_in_recipes = items.product_in_recipes

  local recipe_time               = recipes.times[recipe_id]
  local recipe_ingredient_ids     = recipes.ingredient_ids[recipe_id]
  local recipe_ingredient_amounts = recipes.ingredient_amounts[recipe_id]

  local x = recipe_time * rate

  -- print(string.format("%s '%s' x%g (%gs)", print_prefix, recipe_name, x, recipe_time))

  for i=1,#recipe_ingredient_ids do
    local item_id = recipe_ingredient_ids[i]
    local item_rate = recipe_ingredient_amounts[i] * rate
    print_item_and_recipe(recipes, items, item_id, item_rate,
        print_prefix..string.format(" %2u", i), seen_recipes)
  end

end

function print_item_and_recipe(recipes, items, item_id, rate, print_prefix)
  print_prefix = print_prefix or ""

  -- print(string.format("%s '%s' item_id x%g/s", print_prefix, item_id, rate))

  local item_name = items.names[item_id]
  local item_type = items.types[item_id]
  local item_disallowed = item_type >= items.disallowed_val_cutoff

  local product_in_recipes = item_disallowed and {} or items.product_in_recipes[item_id]
  local disallowed_recipes = 0

  for i=1,#product_in_recipes do
    local recipe_id   = product_in_recipes[i]
    local recipe_allowed = recipes.allowed[recipe_id]

    if recipe_allowed then
      -- don't allow using it again
      recipes.allowed[recipe_id] = false

      local recipe_name = recipes.names[recipe_id]
      local recipe_time = recipes.times[recipe_id]
      local recipe_product_ids     = recipes.product_ids[recipe_id]
      local recipe_product_amounts = recipes.product_amounts[recipe_id]

      -- find amount of item produced in this recipe
      local amount = 0
      for p=1,#recipe_product_ids do
        local product_id = recipe_product_ids[p]
        if product_id == item_id then
          assert(amount == 0)
          amount = recipe_product_amounts[p]
        end
      end
      assert(amount > 0)

      local recipe_rate = rate / amount
      local recipe_x = recipe_time * recipe_rate

      print(string.format("%s '%s' %g/s - x%g recipe '%s' x%g %gs",
          print_prefix, item_name, rate, recipe_x, recipe_name, amount, recipe_time))

      print_recipe_and_ingredients(recipes, items, recipe_id, recipe_rate, print_prefix)

      recipes.allowed[recipe_id] = true
    else
      disallowed_recipes = disallowed_recipes + 1
    end
  end

  -- print no recipes or no allowed recipes for this item exist
  if #product_in_recipes == disallowed_recipes then
    print(string.format("%s '%s' %g/s", print_prefix, item_name, rate))
  end

end

function main(args)

  local items =
  {
    names_to_ids = {}
   ,names = {}
   ,types = {}
   ,ingredient_in_recipes = {}
   ,product_in_recipes = {}
   ,type_names_to_vals = {
      item = 1
     ,fluid = 2
     ,resource = 4
    }
   ,disallowed_val_cutoff = 2
  }

  local recipes =
  {
    names_to_ids = {}
   ,names = {}
   ,times = {}
   ,ingredient_ids = {}
   ,ingredient_amounts = {}
   ,product_ids = {}
   ,product_amounts = {}
   ,allowed = {}
   ,disallowed_patterns =
    {
      "fill%-.*%-barrel"
     ,"empty%-.*%-barrel"
     ,"kovarex"
    }
  }

  local help_string = string.format(
      [[Usage: factorio_calc item_name [options]
        Prints the items needed to produce the given item item_name at the
        given rate, default 1 item/s.

        item_name           the name of the item to produce
        options
          -h --help         print help text
          -r --rate         the rate in items per second
          --items           print all item names
          -i --item         print items matching the given pattern
          --recipes         print all recipe names
          -rp --recipe      print recipes matching the given pattern
          --expand-fluids   expand fluid production sub-trees (forced if item_name is a fluid)
      ]]
      )

  local item_name = nil
  local rate = 1 -- in items per second
  local item_pattern = nil
  local recipe_pattern = nil

  -- used to skip some number of args already consumed
  local skip = 0

  for i=1,#args do
    if skip > 0 then
      skip = skip - 1
    else
      local arg = args[i]

      if string.find(arg, "^%-") == 1 then -- begins with -

        if arg == "-h" or arg == "--help" then

          print(help_string)
          return os.exit(0)

        elseif arg == "--items" then

          item_pattern = ""

        elseif arg == "-i" or arg == "--item" then

          item_pattern = args[i+1]
          skip = 1

          if not item_pattern then
            print(string.format("Error parsing %s %s", arg, args[i+1]))
            return os.exit(1)
          end

        elseif arg == "--recipes" then

          recipe_pattern = ""

        elseif arg == "-rp" or arg == "--recipe" then

          recipe_pattern = args[i+1]
          skip = 1

          if not recipe_pattern then
            print(string.format("Error parsing %s %s", arg, args[i+1]))
            return os.exit(1)
          end

        elseif arg == "-r" or arg == "--rate" then

          rate = tonumber(args[i+1])
          skip = 1

          if not rate then
            print(string.format("Error parsing %s %s", arg, args[i+1]))
            return os.exit(1)
          end

        elseif arg == "--expand-fluids" then

          items.disallowed_val_cutoff = 2*items.type_names_to_vals.fluid

        else

          print(string.format("Error parsing unknown option %s", arg))
          return os.exit(1)

        end

      else -- item name

        item_name = arg

      end
    end
  end

  if item_name == nil  and item_pattern == nil and recipe_pattern == nil then
    print(string.format("Error no item_name given"))
    return os.exit(1)
  end

  parse_recipes(recipes, items)

  if item_pattern ~= nil then
    local item_names = items.names

    print(string.format("Looking for items matching '%s'", item_pattern))

    for i=1,#item_names do
      local item_name = item_names[i]

      if string.find(item_name, item_pattern) ~= nil then
        print(string.format(" '%s'", item_name))
      end
    end

  end

  if recipe_pattern ~= nil then
    local recipe_names = recipes.names

    print(string.format("Looking for recipes matching '%s'", recipe_pattern))

    for i=1,#recipe_names do
      local recipe_name = recipe_names[i]

      if string.find(recipe_name, recipe_pattern) ~= nil then
        print(string.format(" '%s'", recipe_name))
      end
    end

  end

  if item_pattern ~= nil or recipe_pattern ~= nil then
    return os.exit(0)
  end

  local item_id = items.names_to_ids[item_name]

  if item_id == nil then
    print(string.format("Error unknown item %s", item_name))
    return os.exit(1)
  end

  if #(items.product_in_recipes[item_id]) == 0 then
    print(string.format("Item '%s' is the product of no known recipes", item_name))
    return os.exit(0)
  end

  local item_is_fluid = (items.types[item_id] % (2*items.type_names_to_vals.fluid)) >= items.type_names_to_vals.fluid
  if item_is_fluid and items.disallowed_val_cutoff <= items.type_names_to_vals.fluid then
    items.disallowed_val_cutoff = 2*items.type_names_to_vals.fluid
  end

  print_item_and_recipe(recipes, items, item_id, rate)

  return os.exit(0)
end

main(arg)
