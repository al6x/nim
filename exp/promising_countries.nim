import base/[basem, jsonm, saym]
import ext/csvm
import pl0t

# Reading data -------------------------------------------------------------------------------------
const data_path = "./exp/promising_countries"

# Country age structure
# https://en.wikipedia.org/wiki/List_of_countries_by_age_structure
let cage = map_csv(
  fmt"{data_path}/countries_age_2017.csv", separator = '\t',
  map = (row) => (
    country:  row("country").to_lower.trim,
    age_0_14: row("0-14").parse_float.some
  )
)

# Country spending relative to GDP
# https://en.wikipedia.org/wiki/List_of_countries_by_government_spending_as_percentage_of_GDP
let cspending = map_csv(
  fmt"{data_path}/countries_spending_relative_to_gdp_2020.csv", separator = '\t',
  map = (row) => (
    country:      row("country").to_lower.trim,
    gov_spending: try: row("expendure % of gdp").parse_float.some except: float.none
  )
)

# Country economic complexity score
# https://en.wikipedia.org/wiki/List_of_countries_by_economic_complexity
let ceconomy = map_csv(
  fmt"{data_path}/economic_complexity_2018.csv", separator = '\t',
  map = (row) => (
    country:       row("Country").to_lower.trim,
    economy_score: try: row("Economic complexity index (2018)").parse_float.some except: float.none
  )
)


# Merging tables and checking for errors -----------------------------------------------------------
type CStats = tuple
  country:       string
  age_0_14:      Option[float]
  gov_spending:  Option[float]
  economy_score: Option[float]


var table: seq[CStats] = block:
  let minor_countries = read_file(fmt"{data_path}/minor_countries.txt").split("\n")
  let countries = (cage.pick(country) & cspending.pick(country) & ceconomy.pick(country)).unique.sort

  var table: seq[CStats]
  for country in countries:
    let age_0_14      = cage.fget((v) => v.country == country).map((v) => v.age_0_14).flatten
    let gov_spending  = cspending.fget((v) => v.country == country).map((v) => v.gov_spending).flatten
    var economy_score = ceconomy.fget((v) => v.country == country).map((v) => v.economy_score).flatten

    if (age_0_14.is_none or gov_spending.is_none or economy_score.is_none):
      if country in minor_countries:
        continue # Ignoring minor countries without data to avoid the noise
      else:
        echo fmt"warn: missing some data for {country}"

    # Economic complexity score missing for Taiwan, setting it explicitly as high,
    # as we know Taiwan is high tech country and we don't want to miss it as it's important country
    if country == "taiwan" and economy_score.is_none:
      echo "warn: setting economic score for taiwan manually"
      economy_score = 2.0.some

    table.add (country: country, age_0_14: age_0_14, gov_spending: gov_spending,
      economy_score: economy_score)

  table


# # Plotting -----------------------------------------------------------------------------------------
plot_base_url  = "http://demos.pl0t.com"

# Can be seen as http://demos.pl0t.com/promising_countries.json:table
plot "/promising_countries.json", table, jo {
  columns: [
    { id: "country",       type: "string" },
    { id: "economy_score", type: "number", format: { type: "line"} },
    { id: "gov_spending",  type: "number", format: { type: "line", ticks: [50, 100] } },
    { id: "age_0_14",      type: "number", format: { type: "line", ticks: [50, 100] } }
  ],
  column_filters: { economy_score: [">", 1.5] },
  wsort:          { economy_score: 1.6, gov_spending: -1.0, age_0_14: 1.0 },
}

say "finished"