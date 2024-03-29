import base, mono/core
import ../../model, ../palette, ../location

type QueryInput* = ref object of Component
  # Complicated input, it needs to store query as string separately from the location, and also
  # it should update location when query string changed
  filter*:       Filter
  set_location*: proc(l: Location)
  query*:        string

proc after_create*(self: QueryInput) =
  self.query = self.filter.to_s # Setting the initial query from url

proc set_query*(self: QueryInput, q: string) =
  self.query  = q
  self.filter = Filter.parse(q)
  self.set_location(Location(kind: filter, filter: self.filter, page: 1))

proc render*(self: QueryInput): El =
  alter_el el(PSearchField, ()):
    it.value self.query
    it.on_input proc (e: InputEvent) = self.set_query(e.value.get_str)

proc QueryInputWithRedirect*(set_location: proc(l: Location)): El =
  alter_el el(PSearchField, ()):
    it.value ""
    it.on_input proc (e: InputEvent) =
      set_location Location(kind: filter, filter: Filter.parse(e.value.get_str), page: 1)