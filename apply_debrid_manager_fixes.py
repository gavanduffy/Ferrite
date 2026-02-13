import sys

def apply_fixes():
    with open("Ferrite/ViewModels/DebridManager.swift", "r") as f:
        lines = f.readlines()

    # pollTransfers: line 194-196
    # 194:                await MainActor.run {
    # 195:                    self.transferProgress = newProgressMap
    # 196:                }
    lines[193] = "                self.transferProgress = newProgressMap\n"
    lines[194] = ""
    lines[195] = ""

    # pollTransfers: line 199-201
    # 199:                await MainActor.run {
    # 200:                    logManager?.error("Transfer polling error: \(error.localizedDescription)", showToast: false)
    # 201:                }
    lines[198] = "                logManager?.error(\"Transfer polling error: \(error.localizedDescription)\", showToast: false)\n"
    lines[199] = ""
    lines[200] = ""

    # scheduleRemoteDelete: line 221-229
    # 221:            await MainActor.run {
    # 222:                Task {
    # 223:                    await self?.deleteCloudDownload(download)
    # 224:                    // Remove from scheduledDeletes map on completion
    # 225:                    await MainActor.run {
    # 226:                        self?.scheduledDeletes.removeValue(forKey: download.id)
    # 227:                    }
    # 228:                }
    # 229:            }
    #
    # New logic:
    # await self?.deleteCloudDownload(download)
    # await MainActor.run { [weak self] in
    #     self?.scheduledDeletes.removeValue(forKey: download.id)
    # }

    # Wait, I should find the exact indices. Line 221 is index 220.
    lines[220] = "            await self?.deleteCloudDownload(download)\n"
    lines[221] = "            await MainActor.run { [weak self] in\n"
    lines[222] = "                self?.scheduledDeletes.removeValue(forKey: download.id)\n"
    lines[223] = "            }\n"
    for i in range(224, 229):
        lines[i] = ""

    # fetchStreamableLink: line 255-257
    lines[254] = "            logManager?.error(\"DebridManager: No provider available to fetch streamable link\", showToast: false)\n"
    lines[255] = ""
    lines[256] = ""

    # fetchStreamableLink: line 265-267
    lines[264] = "                self.downloadUrl = streamable\n"
    lines[265] = ""
    lines[266] = ""

    # fetchStreamableLink: line 273-275
    lines[272] = "            self.downloadUrl = link\n"
    lines[273] = ""
    lines[274] = ""

    # Filter out empty lines to avoid gaps
    with open("Ferrite/ViewModels/DebridManager.swift", "w") as f:
        f.writelines([line for line in lines if line != ""])

if __name__ == "__main__":
    apply_fixes()
