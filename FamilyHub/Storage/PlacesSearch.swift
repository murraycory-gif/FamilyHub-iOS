    private func fillQuick(around location: CLLocation) async {
        message = nil
        var seen = Set<String>()
        var result: [NearbyPlace] = []
        if let named = try? await searchNamed("restaurants", around: location, requireFood: false) {
            merge(named, into: &result, seen: &seen)
        }
        places = sortedPlaces(result)
        if places.isEmpty {
            message = "Looking for more places near \(areaName)…"
        }
    }

    private func fillMore(around location: CLLocation) async {
        var seen = Set(places.map(\.id))
        for item in places {
            seen.insert(item.name.lowercased() + String(format: "-%.3f-%.3f", item.coordinate.latitude, item.coordinate.longitude))
        }
        var result = places
        async let fast = searchNamed("fast food", around: location, requireFood: false)
        async let pizza = searchNamed("pizza", around: location, requireFood: false)
        async let coffee = searchNamed("coffee", around: location, requireFood: false)
        async let tacos = searchNamed("tacos", around: location, requireFood: false)
        async let poi = searchPOIs(around: location)
        async let osm = searchOSM(around: location)

        func add(_ batch: [NearbyPlace]) {
            merge(batch, into: &result, seen: &seen)
            places = sortedPlaces(result)
        }

        if let batch = try? await fast { add(batch) }
        if let batch = try? await pizza { add(batch) }
        if let batch = try? await coffee { add(batch) }
        if let batch = try? await tacos { add(batch) }
        if let batch = try? await poi { add(batch) }
        if let batch = try? await osm { add(batch) }

        if places.isEmpty {
            message = "No restaurants found near \(areaName)."
        } else {
            message = nil
        }
    }