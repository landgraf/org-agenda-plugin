.pragma library

function emptySnapshot() {
  return { generatedAt: "", days: [], next: [], error: "" }
}

function parseSnapshot(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (e) {
    return { generatedAt: "", days: [], next: [], error: "Could not parse agenda output" }
  }
  if (!data || typeof data !== "object") return null
  return {
    generatedAt: String(data.generatedAt || ""),
    days: Array.isArray(data.days) ? data.days : [],
    next: Array.isArray(data.next) ? data.next : [],
    error: String(data.error || "")
  }
}

function fileUrlToPath(url) {
  var s = String(url || "")
  if (s.indexOf("file://") === 0) s = s.substring(7)
  try {
    return decodeURIComponent(s)
  } catch (e) {
    return s
  }
}

function todayItems(snapshot) {
  var days = snapshot && snapshot.days ? snapshot.days : []
  return days.length > 0 && Array.isArray(days[0].items) ? days[0].items : []
}

function openItems(items) {
  return items.filter(function(item) { return item.done !== true })
}

// Overdue scheduled items, or deadlines that are due today or already past.
function isUrgent(item) {
  if (!item || item.done === true) return false
  if (item.type === "past-scheduled") return true
  if (item.type === "deadline") return true
  return false
}

function urgentCount(snapshot) {
  return todayItems(snapshot).filter(isUrgent).length
}

function glyph(item) {
  var type = item ? String(item.type || "") : ""
  if (item && item.done === true) return ""
  if (type === "deadline" || type === "upcoming-deadline") return ""
  if (type === "scheduled" || type === "past-scheduled") return ""
  if (type === "todo") return ""
  return ""
}

function barText(snapshot) {
  if (snapshot && snapshot.error) return " !"
  var count = openItems(todayItems(snapshot)).length
  return count > 0 ? " " + count : ""
}

function tooltip(snapshot) {
  if (!snapshot || snapshot.generatedAt === "" && !snapshot.error) return "Org agenda: loading…"
  if (snapshot.error) return "Org agenda: " + snapshot.error
  var open = openItems(todayItems(snapshot)).length
  var urgent = urgentCount(snapshot)
  var text = open === 0 ? "Nothing on the agenda today" : open + (open === 1 ? " item" : " items") + " today"
  if (urgent > 0) text += " · " + urgent + " overdue or due"
  return text
}

var weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function dayLabel(day) {
  if (!day) return ""
  if (day.offset === 0) return "Today"
  if (day.offset === 1) return "Tomorrow"
  var parts = String(day.date || "").split("-")
  if (parts.length !== 3) return String(day.date || "")
  var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
  return weekdays[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
}

// Days worth showing in the panel: today always, later days only when they
// have something on them.
function visibleDays(snapshot) {
  var days = snapshot && snapshot.days ? snapshot.days : []
  return days.filter(function(day) {
    return day.offset === 0 || (Array.isArray(day.items) && day.items.length > 0)
  })
}

function meta(item) {
  if (!item) return ""
  var parts = []
  if (item.time) parts.push(String(item.time))
  var extra = String(item.extra || "").replace(/:$/, "")
  if (extra !== "" && extra !== "Scheduled" && extra !== "Deadline") parts.push(extra)
  else if (extra === "Deadline") parts.push("Deadline")
  if (item.category) parts.push(String(item.category))
  var tags = item.tags ? Array.prototype.slice.call(item.tags) : []
  if (tags.length > 0) parts.push(":" + tags.join(":") + ":")
  return parts.join(" · ")
}

function relativeTime(iso, nowMs) {
  if (!iso) return ""
  var t = Date.parse(String(iso).replace(/([+-]\d\d)(\d\d)$/, "$1:$2"))
  if (isNaN(t)) return ""
  var sec = Math.max(0, Math.round((nowMs - t) / 1000))
  if (sec < 60) return "just now"
  if (sec < 3600) return Math.floor(sec / 60) + " min ago"
  return Math.floor(sec / 3600) + " h ago"
}
