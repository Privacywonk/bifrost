#!/usr/bin/env python
# vim: ai ts=4 sts=4 et sw=4

import time
from pygsm import GsmModem

gsm = GsmModem(port="/dev/ttyUSB2").boot()

csq = gsm.signal_strength()
approx_dBm =  ((-113) + (2 * csq))

csq_marginal = 9
csq_ok = 14
csq_good = 19
csq_excellent = 30

def csq_name(csq):
    if csq <= csq_marginal:
        return 'marginal'
    elif csq <= csq_ok:
        return 'ok'
    elif csq <= csq_good:
        return 'good'
    elif csq <= csq_excellent:
        return 'excellent'
    else:
        return 'searching'

print 'CSQ: ',csq,'/',csq_excellent,'(',approx_dBm,'dBm) - ',csq_name(csq)
