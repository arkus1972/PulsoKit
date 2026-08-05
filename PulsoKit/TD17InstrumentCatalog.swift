import Foundation

struct TD17InstrumentDefinition {
    let name: String
    let group: String
}

enum TD17InstrumentCatalog {
    // Roland TD-17 Data List v2.00, instrument IDs 000...310.
    static let instruments: [TD17InstrumentDefinition] = [
        TD17InstrumentDefinition(name: "OFF", group: "OFF"), // 000
        TD17InstrumentDefinition(name: "Maple K", group: "KICK"), // 001
        TD17InstrumentDefinition(name: "Birch K", group: "KICK"), // 002
        TD17InstrumentDefinition(name: "Beech K", group: "KICK"), // 003
        TD17InstrumentDefinition(name: "Deep Shell K", group: "KICK"), // 004
        TD17InstrumentDefinition(name: "Solid K", group: "KICK"), // 005
        TD17InstrumentDefinition(name: "18\"Maple K", group: "KICK"), // 006
        TD17InstrumentDefinition(name: "18\"Open K", group: "KICK"), // 007
        TD17InstrumentDefinition(name: "20\"Solid K", group: "KICK"), // 008
        TD17InstrumentDefinition(name: "24\"Open K", group: "KICK"), // 009
        TD17InstrumentDefinition(name: "PlasticBeaterK", group: "KICK"), // 010
        TD17InstrumentDefinition(name: "WoodenBeater K", group: "KICK"), // 011
        TD17InstrumentDefinition(name: "Soft Beater K", group: "KICK"), // 012
        TD17InstrumentDefinition(name: "Resonance K", group: "KICK"), // 013
        TD17InstrumentDefinition(name: "Close Mic 1 K", group: "KICK"), // 014
        TD17InstrumentDefinition(name: "Close Mic 2 K", group: "KICK"), // 015
        TD17InstrumentDefinition(name: "Close Mic 3 K", group: "KICK"), // 016
        TD17InstrumentDefinition(name: "Off Mic K", group: "KICK"), // 017
        TD17InstrumentDefinition(name: "Half-Proc 1 K", group: "KICK"), // 018
        TD17InstrumentDefinition(name: "Half-Proc 2 K", group: "KICK"), // 019
        TD17InstrumentDefinition(name: "Tight K", group: "KICK PROC/ELEC"), // 020
        TD17InstrumentDefinition(name: "Tight Cut K", group: "KICK PROC/ELEC"), // 021
        TD17InstrumentDefinition(name: "Retro Dance K", group: "KICK PROC/ELEC"), // 022
        TD17InstrumentDefinition(name: "House K", group: "KICK PROC/ELEC"), // 023
        TD17InstrumentDefinition(name: "Drum'n Bass K", group: "KICK PROC/ELEC"), // 024
        TD17InstrumentDefinition(name: "Break Beats K", group: "KICK PROC/ELEC"), // 025
        TD17InstrumentDefinition(name: "Impact K", group: "KICK PROC/ELEC"), // 026
        TD17InstrumentDefinition(name: "Tronic K", group: "KICK PROC/ELEC"), // 027
        TD17InstrumentDefinition(name: "ElectroKnock K", group: "KICK PROC/ELEC"), // 028
        TD17InstrumentDefinition(name: "Lo-Fi K", group: "KICK PROC/ELEC"), // 029
        TD17InstrumentDefinition(name: "Reverse K", group: "KICK PROC/ELEC"), // 030
        TD17InstrumentDefinition(name: "R-8 Low K", group: "KICK PROC/ELEC"), // 031
        TD17InstrumentDefinition(name: "TR-808 K", group: "KICK PROC/ELEC"), // 032
        TD17InstrumentDefinition(name: "TR-909 K", group: "KICK PROC/ELEC"), // 033
        TD17InstrumentDefinition(name: "TR-909 Wood K", group: "KICK PROC/ELEC"), // 034
        TD17InstrumentDefinition(name: "Analog K", group: "KICK PROC/ELEC"), // 035
        TD17InstrumentDefinition(name: "Mahogany S", group: "SNARE"), // 036
        TD17InstrumentDefinition(name: "Mahogany SR", group: "SNARE"), // 037
        TD17InstrumentDefinition(name: "Maple S", group: "SNARE"), // 038
        TD17InstrumentDefinition(name: "Maple SR", group: "SNARE"), // 039
        TD17InstrumentDefinition(name: "Steel S", group: "SNARE"), // 040
        TD17InstrumentDefinition(name: "Steel SR", group: "SNARE"), // 041
        TD17InstrumentDefinition(name: "Brass S", group: "SNARE"), // 042
        TD17InstrumentDefinition(name: "Brass SR", group: "SNARE"), // 043
        TD17InstrumentDefinition(name: "Aluminium S", group: "SNARE"), // 044
        TD17InstrumentDefinition(name: "Aluminium SR", group: "SNARE"), // 045
        TD17InstrumentDefinition(name: "Deep Shell S", group: "SNARE"), // 046
        TD17InstrumentDefinition(name: "Deep Shell SR", group: "SNARE"), // 047
        TD17InstrumentDefinition(name: "MaplePiccolo S", group: "SNARE"), // 048
        TD17InstrumentDefinition(name: "MaplePiccoloSR", group: "SNARE"), // 049
        TD17InstrumentDefinition(name: "Brush S", group: "SNARE"), // 050
        TD17InstrumentDefinition(name: "Brush SR", group: "SNARE"), // 051
        TD17InstrumentDefinition(name: "Cross Stick 1", group: "CROSS STICK"), // 052
        TD17InstrumentDefinition(name: "Cross Stick 2", group: "CROSS STICK"), // 053
        TD17InstrumentDefinition(name: "Cross Stick 3", group: "CROSS STICK"), // 054
        TD17InstrumentDefinition(name: "Cross Stick 4", group: "CROSS STICK"), // 055
        TD17InstrumentDefinition(name: "Cross Stick 5", group: "CROSS STICK"), // 056
        TD17InstrumentDefinition(name: "Cross Stick 6", group: "CROSS STICK"), // 057
        TD17InstrumentDefinition(name: "Cross Stick 7", group: "CROSS STICK"), // 058
        TD17InstrumentDefinition(name: "Cross Stick 8", group: "CROSS STICK"), // 059
        TD17InstrumentDefinition(name: "Cross Stick 9", group: "CROSS STICK"), // 060
        TD17InstrumentDefinition(name: "Cross Stick 10", group: "CROSS STICK"), // 061
        TD17InstrumentDefinition(name: "Radio S", group: "SNR PROC/ELEC"), // 062
        TD17InstrumentDefinition(name: "Short Buzz S", group: "SNR PROC/ELEC"), // 063
        TD17InstrumentDefinition(name: "Dense Click S", group: "SNR PROC/ELEC"), // 064
        TD17InstrumentDefinition(name: "Drum'n Bass S", group: "SNR PROC/ELEC"), // 065
        TD17InstrumentDefinition(name: "House S", group: "SNR PROC/ELEC"), // 066
        TD17InstrumentDefinition(name: "House Low S", group: "SNR PROC/ELEC"), // 067
        TD17InstrumentDefinition(name: "Hip Hop S", group: "SNR PROC/ELEC"), // 068
        TD17InstrumentDefinition(name: "Hop S", group: "SNR PROC/ELEC"), // 069
        TD17InstrumentDefinition(name: "Ambient Snap S", group: "SNR PROC/ELEC"), // 070
        TD17InstrumentDefinition(name: "Clap S", group: "SNR PROC/ELEC"), // 071
        TD17InstrumentDefinition(name: "Dirty Clap S", group: "SNR PROC/ELEC"), // 072
        TD17InstrumentDefinition(name: "Retro Dance S", group: "SNR PROC/ELEC"), // 073
        TD17InstrumentDefinition(name: "TR-808 S", group: "SNR PROC/ELEC"), // 074
        TD17InstrumentDefinition(name: "TR-808 SR", group: "SNR PROC/ELEC"), // 075
        TD17InstrumentDefinition(name: "TR-909 S", group: "SNR PROC/ELEC"), // 076
        TD17InstrumentDefinition(name: "TR-909 SR", group: "SNR PROC/ELEC"), // 077
        TD17InstrumentDefinition(name: "Analog 1 S", group: "SNR PROC/ELEC"), // 078
        TD17InstrumentDefinition(name: "Analog 2 S", group: "SNR PROC/ELEC"), // 079
        TD17InstrumentDefinition(name: "TR-808 X Stick", group: "SNR PROC/ELEC"), // 080
        TD17InstrumentDefinition(name: "TR-909 X Stick", group: "SNR PROC/ELEC"), // 081
        TD17InstrumentDefinition(name: "10\"Maple T1", group: "TOM"), // 082
        TD17InstrumentDefinition(name: "10\"Maple T1R", group: "TOM"), // 083
        TD17InstrumentDefinition(name: "12\"Maple T2", group: "TOM"), // 084
        TD17InstrumentDefinition(name: "12\"Maple T2R", group: "TOM"), // 085
        TD17InstrumentDefinition(name: "13\"Maple T3", group: "TOM"), // 086
        TD17InstrumentDefinition(name: "13\"Maple T3R", group: "TOM"), // 087
        TD17InstrumentDefinition(name: "16\"Maple T4", group: "TOM"), // 088
        TD17InstrumentDefinition(name: "16\"Maple T4R", group: "TOM"), // 089
        TD17InstrumentDefinition(name: "12\"Birch T1", group: "TOM"), // 090
        TD17InstrumentDefinition(name: "12\"Birch T1R", group: "TOM"), // 091
        TD17InstrumentDefinition(name: "14\"Birch T2", group: "TOM"), // 092
        TD17InstrumentDefinition(name: "14\"Birch T2R", group: "TOM"), // 093
        TD17InstrumentDefinition(name: "16\"Birch T3", group: "TOM"), // 094
        TD17InstrumentDefinition(name: "16\"Birch T3R", group: "TOM"), // 095
        TD17InstrumentDefinition(name: "18\"Birch T4", group: "TOM"), // 096
        TD17InstrumentDefinition(name: "18\"Birch T4R", group: "TOM"), // 097
        TD17InstrumentDefinition(name: "10\"Beech T1", group: "TOM"), // 098
        TD17InstrumentDefinition(name: "10\"Beech T1R", group: "TOM"), // 099
        TD17InstrumentDefinition(name: "12\"Beech T2", group: "TOM"), // 100
        TD17InstrumentDefinition(name: "12\"Beech T2R", group: "TOM"), // 101
        TD17InstrumentDefinition(name: "13\"Beech T3", group: "TOM"), // 102
        TD17InstrumentDefinition(name: "13\"Beech T3R", group: "TOM"), // 103
        TD17InstrumentDefinition(name: "16\"Beech T4", group: "TOM"), // 104
        TD17InstrumentDefinition(name: "16\"Beech T4R", group: "TOM"), // 105
        TD17InstrumentDefinition(name: "10\"Shallow T1", group: "TOM"), // 106
        TD17InstrumentDefinition(name: "10\"Shallow T1R", group: "TOM"), // 107
        TD17InstrumentDefinition(name: "12\"Shallow T2", group: "TOM"), // 108
        TD17InstrumentDefinition(name: "12\"Shallow T2R", group: "TOM"), // 109
        TD17InstrumentDefinition(name: "13\"Shallow T3", group: "TOM"), // 110
        TD17InstrumentDefinition(name: "13\"Shallow T3R", group: "TOM"), // 111
        TD17InstrumentDefinition(name: "16\"Shallow T4", group: "TOM"), // 112
        TD17InstrumentDefinition(name: "16\"Shallow T4R", group: "TOM"), // 113
        TD17InstrumentDefinition(name: "10\"Brush T1", group: "TOM"), // 114
        TD17InstrumentDefinition(name: "10\"TomRimClick", group: "TOM"), // 115
        TD17InstrumentDefinition(name: "12\"Brush T2", group: "TOM"), // 116
        TD17InstrumentDefinition(name: "12\"TomRimClick", group: "TOM"), // 117
        TD17InstrumentDefinition(name: "13\"Brush T3", group: "TOM"), // 118
        TD17InstrumentDefinition(name: "13\"TomRimClick", group: "TOM"), // 119
        TD17InstrumentDefinition(name: "16\"Brush T4", group: "TOM"), // 120
        TD17InstrumentDefinition(name: "16\"TomRimClick", group: "TOM"), // 121
        TD17InstrumentDefinition(name: "TR-808 T1", group: "TOM PROC/ELEC"), // 122
        TD17InstrumentDefinition(name: "TR-808 T2", group: "TOM PROC/ELEC"), // 123
        TD17InstrumentDefinition(name: "TR-808 T3", group: "TOM PROC/ELEC"), // 124
        TD17InstrumentDefinition(name: "TR-808 T4", group: "TOM PROC/ELEC"), // 125
        TD17InstrumentDefinition(name: "TR-909 T1", group: "TOM PROC/ELEC"), // 126
        TD17InstrumentDefinition(name: "TR-909 T2", group: "TOM PROC/ELEC"), // 127
        TD17InstrumentDefinition(name: "TR-909 T3", group: "TOM PROC/ELEC"), // 128
        TD17InstrumentDefinition(name: "TR-909 T4", group: "TOM PROC/ELEC"), // 129
        TD17InstrumentDefinition(name: "Analog T1", group: "TOM PROC/ELEC"), // 130
        TD17InstrumentDefinition(name: "Analog T2", group: "TOM PROC/ELEC"), // 131
        TD17InstrumentDefinition(name: "Analog T3", group: "TOM PROC/ELEC"), // 132
        TD17InstrumentDefinition(name: "Analog T4", group: "TOM PROC/ELEC"), // 133
        TD17InstrumentDefinition(name: "Elec Bend T1", group: "TOM PROC/ELEC"), // 134
        TD17InstrumentDefinition(name: "Elec Bend T2", group: "TOM PROC/ELEC"), // 135
        TD17InstrumentDefinition(name: "Elec Bend T3", group: "TOM PROC/ELEC"), // 136
        TD17InstrumentDefinition(name: "Elec Bend T4", group: "TOM PROC/ELEC"), // 137
        TD17InstrumentDefinition(name: "14\"Session HH", group: "HI-HAT"), // 138
        TD17InstrumentDefinition(name: "14\"Session HHE", group: "HI-HAT"), // 139
        TD17InstrumentDefinition(name: "13\"Bright HH", group: "HI-HAT"), // 140
        TD17InstrumentDefinition(name: "13\"Bright HHE", group: "HI-HAT"), // 141
        TD17InstrumentDefinition(name: "15\"Heavy HH", group: "HI-HAT"), // 142
        TD17InstrumentDefinition(name: "15\"Heavy HHE", group: "HI-HAT"), // 143
        TD17InstrumentDefinition(name: "14\"Brush HH", group: "HI-HAT"), // 144
        TD17InstrumentDefinition(name: "14\"Brush HHE", group: "HI-HAT"), // 145
        TD17InstrumentDefinition(name: "Tambourine HH", group: "HI-HAT"), // 146
        TD17InstrumentDefinition(name: "Tambourine HHE", group: "HI-HAT"), // 147
        TD17InstrumentDefinition(name: "Drum'n Bass HH", group: "HH PROC/ELEC"), // 148
        TD17InstrumentDefinition(name: "House HH", group: "HH PROC/ELEC"), // 149
        TD17InstrumentDefinition(name: "Sharp House HH", group: "HH PROC/ELEC"), // 150
        TD17InstrumentDefinition(name: "Low Step HH", group: "HH PROC/ELEC"), // 151
        TD17InstrumentDefinition(name: "Jingle HH", group: "HH PROC/ELEC"), // 152
        TD17InstrumentDefinition(name: "TR-808 HH", group: "HH PROC/ELEC"), // 153
        TD17InstrumentDefinition(name: "TR-909 HH", group: "HH PROC/ELEC"), // 154
        TD17InstrumentDefinition(name: "CR-78 HH", group: "HH PROC/ELEC"), // 155
        TD17InstrumentDefinition(name: "CR-78 Metal HH", group: "HH PROC/ELEC"), // 156
        TD17InstrumentDefinition(name: "20\"Dark Rd", group: "RIDE"), // 157
        TD17InstrumentDefinition(name: "20\"Dark RdE", group: "RIDE"), // 158
        TD17InstrumentDefinition(name: "20\"Dark RdB", group: "RIDE"), // 159
        TD17InstrumentDefinition(name: "20\"Bright Rd", group: "RIDE"), // 160
        TD17InstrumentDefinition(name: "20\"Bright RdE", group: "RIDE"), // 161
        TD17InstrumentDefinition(name: "20\"Bright RdB", group: "RIDE"), // 162
        TD17InstrumentDefinition(name: "19\"Light Rd", group: "RIDE"), // 163
        TD17InstrumentDefinition(name: "19\"Light RdE", group: "RIDE"), // 164
        TD17InstrumentDefinition(name: "19\"Light RdB", group: "RIDE"), // 165
        TD17InstrumentDefinition(name: "21\"Dry Dark Rd", group: "RIDE"), // 166
        TD17InstrumentDefinition(name: "21\"DryDark RdE", group: "RIDE"), // 167
        TD17InstrumentDefinition(name: "21\"DryDark RdB", group: "RIDE"), // 168
        TD17InstrumentDefinition(name: "20\"Brush Rd", group: "RIDE"), // 169
        TD17InstrumentDefinition(name: "20\"Brush RdE", group: "RIDE"), // 170
        TD17InstrumentDefinition(name: "20\"Brush RdB", group: "RIDE"), // 171
        TD17InstrumentDefinition(name: "22\"Sizzle Rd", group: "RIDE"), // 172
        TD17InstrumentDefinition(name: "22\"Sizzle RdE", group: "RIDE"), // 173
        TD17InstrumentDefinition(name: "22\"Sizzle RdB", group: "RIDE"), // 174
        TD17InstrumentDefinition(name: "16\"Dark Cr", group: "CRASH"), // 175
        TD17InstrumentDefinition(name: "16\"Dark CrE", group: "CRASH"), // 176
        TD17InstrumentDefinition(name: "18\"Dark Cr", group: "CRASH"), // 177
        TD17InstrumentDefinition(name: "18\"Dark CrE", group: "CRASH"), // 178
        TD17InstrumentDefinition(name: "16\"Bright Cr", group: "CRASH"), // 179
        TD17InstrumentDefinition(name: "16\"Bright CrE", group: "CRASH"), // 180
        TD17InstrumentDefinition(name: "18\"Bright Cr", group: "CRASH"), // 181
        TD17InstrumentDefinition(name: "18\"Bright CrE", group: "CRASH"), // 182
        TD17InstrumentDefinition(name: "16\"Thin Cr", group: "CRASH"), // 183
        TD17InstrumentDefinition(name: "16\"Thin CrE", group: "CRASH"), // 184
        TD17InstrumentDefinition(name: "18\"Thin Cr", group: "CRASH"), // 185
        TD17InstrumentDefinition(name: "18\"Thin CrE", group: "CRASH"), // 186
        TD17InstrumentDefinition(name: "16\"Heavy Cr", group: "CRASH"), // 187
        TD17InstrumentDefinition(name: "16\"Heavy CrE", group: "CRASH"), // 188
        TD17InstrumentDefinition(name: "19\"Heavy Cr", group: "CRASH"), // 189
        TD17InstrumentDefinition(name: "19\"Heavy CrE", group: "CRASH"), // 190
        TD17InstrumentDefinition(name: "17\"Brush Cr", group: "CRASH"), // 191
        TD17InstrumentDefinition(name: "17\"Brush CrE", group: "CRASH"), // 192
        TD17InstrumentDefinition(name: "19\"Brush Cr", group: "CRASH"), // 193
        TD17InstrumentDefinition(name: "19\"Brush CrE", group: "CRASH"), // 194
        TD17InstrumentDefinition(name: "6\"Thin Splash", group: "SPLASH/CHINA"), // 195
        TD17InstrumentDefinition(name: "6\"ThinSplash E", group: "SPLASH/CHINA"), // 196
        TD17InstrumentDefinition(name: "12\"Thin Splash", group: "SPLASH/CHINA"), // 197
        TD17InstrumentDefinition(name: "12\"ThinSplashE", group: "SPLASH/CHINA"), // 198
        TD17InstrumentDefinition(name: "8\"Med Splash", group: "SPLASH/CHINA"), // 199
        TD17InstrumentDefinition(name: "8\"Med Splash E", group: "SPLASH/CHINA"), // 200
        TD17InstrumentDefinition(name: "12\"Med Splash", group: "SPLASH/CHINA"), // 201
        TD17InstrumentDefinition(name: "12\"MedSplash E", group: "SPLASH/CHINA"), // 202
        TD17InstrumentDefinition(name: "16\"China", group: "SPLASH/CHINA"), // 203
        TD17InstrumentDefinition(name: "16\"China E", group: "SPLASH/CHINA"), // 204
        TD17InstrumentDefinition(name: "20\"China", group: "SPLASH/CHINA"), // 205
        TD17InstrumentDefinition(name: "20\"China E", group: "SPLASH/CHINA"), // 206
        TD17InstrumentDefinition(name: "14\"Trash", group: "SPLASH/CHINA"), // 207
        TD17InstrumentDefinition(name: "14\"Trash E", group: "SPLASH/CHINA"), // 208
        TD17InstrumentDefinition(name: "17\"Trash Cr", group: "SPLASH/CHINA"), // 209
        TD17InstrumentDefinition(name: "17\"Trash CrE", group: "SPLASH/CHINA"), // 210
        TD17InstrumentDefinition(name: "Drum'n Bass Rd", group: "CYMBAL OTHERS"), // 211
        TD17InstrumentDefinition(name: "Mainly Bell Rd", group: "CYMBAL OTHERS"), // 212
        TD17InstrumentDefinition(name: "Short&Dirty Rd", group: "CYMBAL OTHERS"), // 213
        TD17InstrumentDefinition(name: "Reverse Rd", group: "CYMBAL OTHERS"), // 214
        TD17InstrumentDefinition(name: "Sweep Cr", group: "CYMBAL OTHERS"), // 215
        TD17InstrumentDefinition(name: "Lo-Fi Cr", group: "CYMBAL OTHERS"), // 216
        TD17InstrumentDefinition(name: "Phase Cr", group: "CYMBAL OTHERS"), // 217
        TD17InstrumentDefinition(name: "Ambient Cr", group: "CYMBAL OTHERS"), // 218
        TD17InstrumentDefinition(name: "TR-808 Cr", group: "CYMBAL OTHERS"), // 219
        TD17InstrumentDefinition(name: "Analog Cr", group: "CYMBAL OTHERS"), // 220
        TD17InstrumentDefinition(name: "Reverse Cr", group: "CYMBAL OTHERS"), // 221
        TD17InstrumentDefinition(name: "Reverse Trash", group: "CYMBAL OTHERS"), // 222
        TD17InstrumentDefinition(name: "Bongo Hi Open", group: "PERCUSSION"), // 223
        TD17InstrumentDefinition(name: "Bongo Hi Slap", group: "PERCUSSION"), // 224
        TD17InstrumentDefinition(name: "Bongo Lo Open", group: "PERCUSSION"), // 225
        TD17InstrumentDefinition(name: "Conga Hi Open", group: "PERCUSSION"), // 226
        TD17InstrumentDefinition(name: "Conga Hi Slap", group: "PERCUSSION"), // 227
        TD17InstrumentDefinition(name: "Conga Lo Open", group: "PERCUSSION"), // 228
        TD17InstrumentDefinition(name: "TimbaleHi Open", group: "PERCUSSION"), // 229
        TD17InstrumentDefinition(name: "Timbale Hi Rim", group: "PERCUSSION"), // 230
        TD17InstrumentDefinition(name: "TimbaleLo Open", group: "PERCUSSION"), // 231
        TD17InstrumentDefinition(name: "Timbale Paila", group: "PERCUSSION"), // 232
        TD17InstrumentDefinition(name: "Cajon Open", group: "PERCUSSION"), // 233
        TD17InstrumentDefinition(name: "Cajon Slap", group: "PERCUSSION"), // 234
        TD17InstrumentDefinition(name: "Cajon Bass", group: "PERCUSSION"), // 235
        TD17InstrumentDefinition(name: "Cowbell 1", group: "PERCUSSION"), // 236
        TD17InstrumentDefinition(name: "Cowbell 1 Tip", group: "PERCUSSION"), // 237
        TD17InstrumentDefinition(name: "Cowbell 2", group: "PERCUSSION"), // 238
        TD17InstrumentDefinition(name: "Cowbell 3", group: "PERCUSSION"), // 239
        TD17InstrumentDefinition(name: "Claves", group: "PERCUSSION"), // 240
        TD17InstrumentDefinition(name: "Maracas", group: "PERCUSSION"), // 241
        TD17InstrumentDefinition(name: "Shaker", group: "PERCUSSION"), // 242
        TD17InstrumentDefinition(name: "Tambourine 1", group: "PERCUSSION"), // 243
        TD17InstrumentDefinition(name: "Tambourine 2", group: "PERCUSSION"), // 244
        TD17InstrumentDefinition(name: "Rain Stick", group: "PERCUSSION"), // 245
        TD17InstrumentDefinition(name: "Vibra-Slap", group: "PERCUSSION"), // 246
        TD17InstrumentDefinition(name: "Cabasa", group: "PERCUSSION"), // 247
        TD17InstrumentDefinition(name: "Surdo Open", group: "PERCUSSION"), // 248
        TD17InstrumentDefinition(name: "Surdo Mute", group: "PERCUSSION"), // 249
        TD17InstrumentDefinition(name: "Surdo Rim", group: "PERCUSSION"), // 250
        TD17InstrumentDefinition(name: "Pandeiro Thumb", group: "PERCUSSION"), // 251
        TD17InstrumentDefinition(name: "Pandeiro Slap", group: "PERCUSSION"), // 252
        TD17InstrumentDefinition(name: "PandeiroJingle", group: "PERCUSSION"), // 253
        TD17InstrumentDefinition(name: "Agogo Hi", group: "PERCUSSION"), // 254
        TD17InstrumentDefinition(name: "Agogo Lo", group: "PERCUSSION"), // 255
        TD17InstrumentDefinition(name: "Caxixi", group: "PERCUSSION"), // 256
        TD17InstrumentDefinition(name: "Cuica Hi", group: "PERCUSSION"), // 257
        TD17InstrumentDefinition(name: "Cuica Lo", group: "PERCUSSION"), // 258
        TD17InstrumentDefinition(name: "Djembe Open", group: "PERCUSSION"), // 259
        TD17InstrumentDefinition(name: "Djembe Slap", group: "PERCUSSION"), // 260
        TD17InstrumentDefinition(name: "Djembe Bass", group: "PERCUSSION"), // 261
        TD17InstrumentDefinition(name: "Pot Drum Side", group: "PERCUSSION"), // 262
        TD17InstrumentDefinition(name: "Pot Drum Mute", group: "PERCUSSION"), // 263
        TD17InstrumentDefinition(name: "Pot Drum Bass", group: "PERCUSSION"), // 264
        TD17InstrumentDefinition(name: "PotDrumRelease", group: "PERCUSSION"), // 265
        TD17InstrumentDefinition(name: "Tabla Na", group: "PERCUSSION"), // 266
        TD17InstrumentDefinition(name: "Tabla Tin", group: "PERCUSSION"), // 267
        TD17InstrumentDefinition(name: "Tabla Tun", group: "PERCUSSION"), // 268
        TD17InstrumentDefinition(name: "Tabla Ge", group: "PERCUSSION"), // 269
        TD17InstrumentDefinition(name: "Tabla Ka", group: "PERCUSSION"), // 270
        TD17InstrumentDefinition(name: "Tabla Ge Slide", group: "PERCUSSION"), // 271
        TD17InstrumentDefinition(name: "Timpani G", group: "PERCUSSION"), // 272
        TD17InstrumentDefinition(name: "Timpani C", group: "PERCUSSION"), // 273
        TD17InstrumentDefinition(name: "Wood Block Hi", group: "PERCUSSION"), // 274
        TD17InstrumentDefinition(name: "Wood Block Lo", group: "PERCUSSION"), // 275
        TD17InstrumentDefinition(name: "Triangle Open", group: "PERCUSSION"), // 276
        TD17InstrumentDefinition(name: "Triangle Close", group: "PERCUSSION"), // 277
        TD17InstrumentDefinition(name: "Crotale", group: "PERCUSSION"), // 278
        TD17InstrumentDefinition(name: "Sleigh Bells", group: "PERCUSSION"), // 279
        TD17InstrumentDefinition(name: "Tree Chimes", group: "PERCUSSION"), // 280
        TD17InstrumentDefinition(name: "Gong", group: "PERCUSSION"), // 281
        TD17InstrumentDefinition(name: "TR-808Cowbell1", group: "PERC PROC/ELEC"), // 282
        TD17InstrumentDefinition(name: "TR-808Cowbell2", group: "PERC PROC/ELEC"), // 283
        TD17InstrumentDefinition(name: "TR-808 Maracas", group: "PERC PROC/ELEC"), // 284
        TD17InstrumentDefinition(name: "TR-808 Claves", group: "PERC PROC/ELEC"), // 285
        TD17InstrumentDefinition(name: "TR-808 Conga", group: "PERC PROC/ELEC"), // 286
        TD17InstrumentDefinition(name: "CR-78 Cowbell", group: "PERC PROC/ELEC"), // 287
        TD17InstrumentDefinition(name: "CR-78 Guiro", group: "PERC PROC/ELEC"), // 288
        TD17InstrumentDefinition(name: "CR-78 Maracas", group: "PERC PROC/ELEC"), // 289
        TD17InstrumentDefinition(name: "CR-78 Tamb", group: "PERC PROC/ELEC"), // 290
        TD17InstrumentDefinition(name: "CR-78 Bongo", group: "PERC PROC/ELEC"), // 291
        TD17InstrumentDefinition(name: "CR-78 Claves", group: "PERC PROC/ELEC"), // 292
        TD17InstrumentDefinition(name: "CR-78MetalBeat", group: "PERC PROC/ELEC"), // 293
        TD17InstrumentDefinition(name: "Clap", group: "SOUND FX"), // 294
        TD17InstrumentDefinition(name: "House Clap", group: "SOUND FX"), // 295
        TD17InstrumentDefinition(name: "Fat Clap", group: "SOUND FX"), // 296
        TD17InstrumentDefinition(name: "TechHouse Clap", group: "SOUND FX"), // 297
        TD17InstrumentDefinition(name: "Noize Clap", group: "SOUND FX"), // 298
        TD17InstrumentDefinition(name: "TR-808 Clap", group: "SOUND FX"), // 299
        TD17InstrumentDefinition(name: "TR-909 Clap", group: "SOUND FX"), // 300
        TD17InstrumentDefinition(name: "Snaps", group: "SOUND FX"), // 301
        TD17InstrumentDefinition(name: "Snappin'", group: "SOUND FX"), // 302
        TD17InstrumentDefinition(name: "Beep", group: "SOUND FX"), // 303
        TD17InstrumentDefinition(name: "Afro Stomp", group: "SOUND FX"), // 304
        TD17InstrumentDefinition(name: "Discovery", group: "SOUND FX"), // 305
        TD17InstrumentDefinition(name: "Super Low", group: "SOUND FX"), // 306
        TD17InstrumentDefinition(name: "ReflectiveBell", group: "SOUND FX"), // 307
        TD17InstrumentDefinition(name: "Reverse&Phase", group: "SOUND FX"), // 308
        TD17InstrumentDefinition(name: "Voice-Haaa", group: "SOUND FX"), // 309
        TD17InstrumentDefinition(name: "Sin 440Hz", group: "SOUND FX"), // 310
    ]

    static func instrument(for id: Int) -> TD17InstrumentDefinition? {
        guard instruments.indices.contains(id) else { return nil }
        return instruments[id]
    }
}
