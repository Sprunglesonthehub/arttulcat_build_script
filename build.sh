git clone https://github.com/Sprunglesonthehub/arttulcat_browser.git && \
cd arttulcat_browser/browser/branding/ && git clone https://github.com/Sprunglesonthehub/arttulcat_branding.git && \
ce arttulcat_branding && mv arttulcat/ ../ && rm -rf arttulcat_branding && \
cd ../../ && \
git clone https://github.com/Sprunglesonthehub/arttulcat_configs.git && \
cd arttulcat_configs && cd mozconfig && mv .mozconfig ../../  && cd ../../ && rm -rf arttulcat_configs && \
./mach bootstrap
./mach clobber
./mach build
