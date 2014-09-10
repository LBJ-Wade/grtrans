import numpy as np

f = open('geodebug.out','r')
data = f.readlines()
f.close()

header = np.array(data[0].split(),dtype=float)
lam = np.array(data[1].split(),dtype=float)
time = np.array(data[2].split(),dtype=float)
r = np.array(data[3].split(),dtype=float)
th = np.array(data[4].split(),dtype=float)
phi = np.array(data[5].split(),dtype=float)
kt = np.array(data[6].split(),dtype=float)
kr = np.array(data[7].split(),dtype=float)
kth = np.array(data[8].split(),dtype=float)
kphi = np.array(data[9].split(),dtype=float)
tpr = np.array(data[10].split(),dtype=float)
tpm = np.array(data[11].split(),dtype=float)

rho = np.array(data[12].split(),dtype=float)
p = np.array(data[13].split(),dtype=float)
b = np.array(data[14].split(),dtype=float)
ut = np.array(data[15].split(),dtype=float)
ur = np.array(data[16].split(),dtype=float)
uth = np.array(data[17].split(),dtype=float)
uphi = np.array(data[18].split(),dtype=float)
bt = np.array(data[19].split(),dtype=float)
br = np.array(data[20].split(),dtype=float)
bth = np.array(data[21].split(),dtype=float)
bphi = np.array(data[22].split(),dtype=float)
n = np.array(data[23].split(),dtype=float)

t = np.array(data[24].split(),dtype=float)
b = np.array(data[25].split(),dtype=float)
g = np.array(data[26].split(),dtype=float)
incang = np.array(data[27].split(),dtype=float)
ji = np.array(data[28].split(),dtype=float)
ki = np.array(data[29].split(),dtype=float)
jq = np.array(data[30].split(),dtype=float)
jv = np.array(data[31].split(),dtype=float)
kq = np.array(data[32].split(),dtype=float)
kv = np.array(data[33].split(),dtype=float)
rhoq = np.array(data[34].split(),dtype=float)
rhov = np.array(data[35].split(),dtype=float)
ii = np.array(data[36].split(),dtype=float)
iq = np.array(data[37].split(),dtype=float)
iu = np.array(data[38].split(),dtype=float)
iv = np.array(data[39].split(),dtype=float)
taui = np.array(data[40].split(),dtype=float)
ju = np.array(data[41].split(),dtype=float)
ku = np.array(data[42].split(),dtype=float)
rhou = np.array(data[43].split(),dtype=float)
