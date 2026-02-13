import sys

def apply_fixes():
    with open("Ferrite/ViewModels/LoggingManager.swift", "r") as f:
        lines = f.readlines()

    # performUndoAction: line 221-224
    # 221:            await MainActor.run {
    # 222:                self.undoAction = nil
    # 223:                self.showToast = false
    # 224:                }

    # Line 221 is index 220
    lines[220] = "                self.undoAction = nil\n"
    lines[221] = "                self.showToast = false\n"
    lines[222] = "" # line 223
    lines[223] = "" # line 224

    with open("Ferrite/ViewModels/LoggingManager.swift", "w") as f:
        f.writelines([line for line in lines if line != ""])

if __name__ == "__main__":
    apply_fixes()
