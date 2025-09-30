This is a very simple script I made originally for c3 Roleplay. All you have to do is setup departments with aceperms to use the commands. It webhooks for every time someone /clockon [department] and every time someone /clockoff [department]. It keeps track of hours for the week and then resets every Sunday and webhooks total hours tracked for each person.

To setup the departments you need to edit the top of server.lua. DO NOT TOUCH shift_data.json.

local departments = {
    ["lsmpd"] = {
        acePermission = "lsmpd.hours",
        Name = "Los Santos Metro Police Department",
        webhook = "WEBHOOK_HERE"
    },
    ["bcso"] = {
        acePermission = "bcso.hours",
        Name = "Blaine County Sheriff's Office",
        webhook = "WEBHOOK_HERE"
    },
    ["safr"] = {
        acePermission = "safr.hours",
        Name = "San Andreas Fire & Rescue",
        webhook = "WEBHOOK_HERE"
    },
    ["sasp"] = {
        acePermission = "sasp.hours",
        Name = "San Andreas State Police",
        webhook = "WEBHOOK_HERE"
    }
}
