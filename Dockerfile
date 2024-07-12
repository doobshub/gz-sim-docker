ARG ROS_DISTRO
FROM ros:${ROS_DISTRO}

#ARG USER=user
#ARG HOME_DIR=/home/${USER}

ENV COLCON_WS=/root/colcon_ws
ENV COLCON_WS_SRC=/root/colcon_ws/src
ENV PYTHONWARNINGS="ignore:setup.py install is deprecated::setuptools.command.install"

ENV DEBIAN_FRONTEND noninteractive

# see https://gazebosim.org/docs/harmonic/install_ubuntu
ARG GZ_VERSION

RUN apt-get update -qq \
    && apt-get install -y \
        wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg\
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null

RUN apt-get update -qq \
    && apt-get install -y \
        gz-${GZ_VERSION} \
        build-essential\
        ros-${ROS_DISTRO}-rcl-interfaces\
        ros-${ROS_DISTRO}-rclcpp\
        ros-${ROS_DISTRO}-builtin-interfaces\
        ros-${ROS_DISTRO}-ros-gz\
        ros-${ROS_DISTRO}-sdformat-urdf\
        ros-${ROS_DISTRO}-vision-msgs\
        ros-${ROS_DISTRO}-actuator-msgs\
        ros-${ROS_DISTRO}-image-transport\
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y git gitk git-gui libgz-sim7-dev rapidjson-dev libopencv-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl \
    && rm -rf /var/lib/apt/lists/*

#RUN useradd -ms /bin/bash ${USER} \
#    && usermod -aG sudo ${USER} \
#    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

#USER ${USER}
#WORKDIR ${HOME_DIR}

RUN mkdir -p ${HOME}/colcon_ws/src \
    && cd ${HOME}/colcon_ws \
    && . /opt/ros/${ROS_DISTRO}/setup.sh \
    && colcon build

RUN mkdir -p ~/ros2_ws/src \
    cd ~/ros2_ws/ \
    colcon build \
    echo "source $HOME/ros2_ws/install/setup.bash" >> ~/.bashrc \
    source ~/.bashrc

RUN git clone --recurse-submodules https://github.com/ArduPilot/ardupilot \
    && cd ~/ardupilot\
    && USER=nobody Tools/environment_install/install-prereqs-ubuntu.sh -y \
    && . ~/.profile 

RUN export GZ_VERSION=garden \
    && sudo bash -c 'wget https://raw.githubusercontent.com/osrf/osrf-rosdep/master/gz/00-gazebo.list -O /etc/ros/rosdep/sources.list.d/00-gazebo.list' \
    && rosdep update \
    && rosdep resolve gz-garden \
    %% cd ~/ros2_ws/ \
    && rosdep install --from-paths src --ignore-src -y

RUN git clone https://github.com/ArduPilot/ardupilot_gazebo.git \
    && cd ~/ardupilot_gazebo \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && make -j4

RUN export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:$GZ_SIM_SYSTEM_PLUGIN_PATH \
    && export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:$GZ_SIM_RESOURCE_PATH \
    && echo 'export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH}' >> ~/.bashrc \
    echo 'export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:${GZ_SIM_RESOURCE_PATH}' >> ~/.bashrc \
    && source ~/.bashrc

WORKDIR $HOME

RUN git clone https://github.com/ArduPilot/SITL_Models.git

#RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc \
#    && echo "source ${COLCON_WS}/install/setup.bash" >> ~/.bashrc \
#    && echo "source ${HOME_DIR}/ros2_ws/install/setup.bash" >> ~/.bashrc


RUN echo "export GZ_VERSION=garden" >> ~/.bashrc \
    && echo "export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH}" >> ~/.bashrc \
    && echo "export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:$HOME/SITL_Models/Gazebo/models:$HOME/SITL_Models/Gazebo/worlds:$GZ_SIM_RESOURCE_PATH" >> ~/.bashrc

RUN apt install ros-humble-mavros*

gz sim -v4 -r r1_rover_runway.sdf

CMD gz sim
