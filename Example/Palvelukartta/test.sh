#!/bin/sh -e

#  test.sh
#  Palvelukartta
#
#  Created by Rasmus Sten on 2012-05-23.
#  Copyright (c) 2012 Rasmus Sten. All rights reserved.

ulimit -c unlimited
$1
$1 --all-services
$1 --service 25402
echo OK.

