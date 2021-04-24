FROM centos:7

USER root

ENV LANG="en_US.UTF-8"

RUN ln -nsf /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime

WORKDIR /etc/
RUN echo "proxy=http://host.docker.internal:3128" >> yum.conf

RUN yum install -y ctags          \
                   gcc            \
                   gcc-c++        \
                   git            \
                   make           \
                   ncurses        \
                   ncurses-devel  \
                   openssl        \
                   openssl-devel  \
                   python         \
                   python-devel   \
                   python3        \
                   python3-devel  \
                   screen         \
                   sudo           \
                   tree

RUN yum remove -y vim-enhanced vim-common vim-filesystem
RUN yum clean all # makes sense for squashed builds

WORKDIR /etc/
RUN sed -i -e "/^%wheel/ d"         sudoers # remove PASSWORD
RUN sed -i -e "s/^# %wheel/%wheel/" sudoers # activate NOPASSWORD

RUN adduser --home-dir /home/tjeerd tjeerd
RUN usermod -a -G wheel tjeerd

RUN chmod g+wxs .

WORKDIR /home/tjeerd/
COPY run/res/home/ .
RUN echo "hardstatus off" >> .screenrc

WORKDIR /home/tjeerd/
COPY res/home/first_run           .first_run
COPY res/home/run                 .run
COPY res/home/start               .start
COPY res/deploy/coc-settings.json /home/tjeerd/.vim/coc-settings.json

RUN chown tjeerd.tjeerd -R /home/tjeerd

USER tjeerd

RUN mkdir -p /home/tjeerd/.vim/pack/coc/start \
             /home/tjeerd/.config/coc         \
             /home/tjeerd/.vim/autoload       \
             /home/tjeerd/.vim/bundle         \
             /home/tjeerd/bin

RUN sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
RUN sudo curl -sL install-node.now.sh/lts | sudo sh -s -- -y
RUN sudo -E env "PATH=$PATH" npm install -g yarn
RUN curl -LSo /home/tjeerd/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

RUN git clone https://github.com/vim/vim.git /home/tjeerd/tmp/vim
RUN git clone https://github.com/rust-analyzer/rust-analyzer.git /home/tjeerd/tmp/rust-analyzer
RUN git clone --depth=1 https://github.com/rust-lang/rust.vim.git /home/tjeerd/.vim/bundle/rust.vim
RUN git clone --depth=1 https://github.com/vim-syntastic/syntastic.git /home/tjeerd/.vim/bundle/syntastic
RUN git clone https://github.com/neoclide/coc.nvim.git /home/tjeerd/.vim/pack/coc/start/coc.nvim

WORKDIR /home/tjeerd/tmp/vim
RUN sudo ./configure --with-features=huge --enable-pythoninterp
RUN sudo make
RUN sudo make install
RUN sudo ln -s /usr/local/bin/vim /usr/bin/vim

WORKDIR /home/tjeerd/tmp/rust-analyzer
RUN /home/tjeerd/.cargo/bin/cargo xtask install --server
RUN /home/tjeerd/.cargo/bin/cargo install cargo-audit
RUN /home/tjeerd/.cargo/bin/cargo install cargo-edit

RUN sed -i '1s/^/execute pathogen#infect()\n\n/' /home/tjeerd/.vimrc
#RUN sed -i '$a \\nset statusline+=%#warningmsg#\nset statusline+=%{SyntasticStatuslineFlag()}\nset statusline+=%*\nlet g:syntastic_always_populate_loc_list = 1\nlet g:syntastic_auto_loc_list = 1\nlet g:syntastic_check_on_open = 1\nlet g:syntastic_check_on_wq = 0' /home/tjeerd/.vimrc
RUN sed -i '$a \\nlet g:coc_global_extensions = ["coc-json", "coc-rust-analyzer"]' /home/tjeerd/.vimrc
RUN sed -i '15 a set softtabstop=0' ~/.vimrc
RUN sed -i '16 a set smarttab' ~/.vimrc
RUN sed -i '23 a export PATH="$HOME/.cargo/bin:$PATH"' /home/tjeerd/.bash_profile
RUN sed -i 's/set tabstop=4/set tabstop=8/g' ~/.vimrc
RUN sed -i 's/set shiftwidth=2/set shiftwidth=4/g' ~/.vimrc

RUN /home/tjeerd/.cargo/bin/rustup component add rust-src

RUN git clone git@github.com:tlafebre/hub.git /home/tjeerd/hub
WORKDIR /home/tjeerd/hub
RUN /home/tjeerd/.cargo/bin/cargo build --release
RUN cp /home/tjeerd/hub/target/release/hub /home/tjeerd/bin/

WORKDIR /home/tjeerd
RUN sudo rm -rf tmp/

CMD ./.start
