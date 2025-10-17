'''
Make lots of new STASH items so you don't have to manually select them in the Rose GUI. 
Paste into suite app/um/rose-app.conf (without GUI open), then run tidyStashIndices macro.
Each addition should look similar to this:

[namelist:umstash_streq(1)]
dom_name='DALLTH'
isec=50
item=500
package='J_rates'
tim_name='T1H'
use_name='UPL'
'''

import numpy as np

dom_name = 'DALLTH' # Domain.
isec = 50 # UKCA section.
package = 'J_rates' # Whatever you want to call the package.
tim_name = 'T1H' # Time profile.
use_name = 'UPL' # Usage profile.
first_item, last_item = 500, 646 # If you want a whole section.
# Array of all the items we want. Make your own explicit array if only chosing specific items. 
items = np.arange(first_item, last_item+1, dtype=int)

def makeItems(items, dom, sec, pac, tim, use):
 num_items = len(items)
 for index in range(num_items):
   item_num = items[index]
   each_string = "[namelist:umstash_streq({n})]\ndom_name='{d}'\nisec={s}\nitem={i}\npackage={p}\ntim_name='{t}'\nuse_name='{u}'\n"\
                          .format(n=index+1, d=dom, s=sec, i=item_num, p=pac, t=tim, u=use)
   print(each_string)

makeItems(items, dom_name, isec, package, tim_name, use_name)
