# -*- coding: utf-8 -*-
"""
Created on Tue May 24 10:41:50 2016

@author: dahoiv
"""

import os
import util

if __name__ == "__main__":
    os.nice(19)
    import time
    time.sleep(60*60*5)

#    if False:
#        import do_img_registration_LGG_POST as do_img_registration
#        util.setup("LGG_POST_RES/", "LGG")
#    elif False:
#        import do_img_registration_LGG_PRE as do_img_registration
#        util.setup("LGG_PRE_RES/", "LGG")
#    elif False:
#        import do_img_registration_GBM as do_img_registration
#        util.setup("GBM_RES2/", "GBM")

    params = ['Index_value', 'Global_index', 'Mobility', 'Selfcare', 'Activity', 'Pain', 'Anxiety']
    util.mkdir_p("LGG_GBM_RES")

    FOLDER = "LGG_GBM_RES/GBM/"  # "LGG_GBM_RES/GBM"
    util.setup(FOLDER, "GBM")
    util.mkdir_p(FOLDER)
    util.mkdir_p(util.TEMP_FOLDER_PATH)

    for qol_param in params:
        (image_ids, qol) = util.get_image_id_and_qol(qol_param)
        print(image_ids)
        result = util.post_calculations(image_ids)
        for label in result:
            print(label)
            if label == 'img':
                continue
            util.avg_calculation(result[label], label + '_' + qol_param, qol, True, FOLDER)
    util.avg_calculation(result['img'], label, None, True, FOLDER)
    util.sum_calculation(result['img'], label, None, True, FOLDER)
