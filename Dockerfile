ARG ROS_DISTRO
FROM ros:${ROS_DISTRO}

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

RUN git clone --recurse-submodules https://github.com/ArduPilot/ardupilot /root/ardupilot \
    && cd /root/ardupilot \
    && Tools/environment_install/install-prereqs-ubuntu.sh -y \
    && . ~/.profile \
    && ./waf clean

RUN git clone https://github.com/ArduPilot/ardupilot_gazebo.git /root/ardupilot_gazebo \
    && cd /root/ardupilot_gazebo \
    && mkdir build && cd build \
    && cmake .. && make

# Set environment variables
ENV GZ_SIM_SYSTEM_PLUGIN_PATH=/root/ardupilot_gazebo/build:$GZ_SIM_SYSTEM_PLUGIN_PATH
ENV GZ_SIM_RESOURCE_PATH=/root/ardupilot_gazebo/models:/root/ardupilot_gazebo/worlds:$GZ_SIM_RESOURCE_PATH

WORKDIR $HOME

RUN source ros_entrypoint.sh

RUN mkdir -p ${COLCON_WS_SRC}\
    && cd ${COLCON_WS}\
    && . /opt/ros/${ROS_DISTRO}/setup.sh\
    && colcon build

RUN mkdir -p /root/ros2_ws/src \
    && cd /root/ros2_ws/src \
    && git clone https://github.com/itskalvik/ros_sgp_tools.git \
    && cd /root/ros2_ws \
    && colcon build \
    && echo "source $HOME/ros2_ws/install/setup.bash" >> ~/.bashrc \
    && source ~/.bashrc
    
WORKDIR $HOME

RUN git clone https://github.com/ArduPilot/SITL_Models.git

RUN echo "export GZ_VERSION=garden" >> ~/.bashrc
RUN echo "export GZ_SIM_SYSTEM_PLUGIN_PATH=$HOME/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH}" >> ~/.bashrc
RUN echo "export GZ_SIM_RESOURCE_PATH=$HOME/ardupilot_gazebo/models:$HOME/ardupilot_gazebo/worlds:$HOME/SITL_Models/Gazebo/models:$HOME/SITL_Models/Gazebo/worlds:$GZ_SIM_RESOURCE_PATH" >> ~/.bashrc

RUN apt-get update \
    && apt-get install -y ros-${ROS_DISTRO}-mavros* \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

CMD gz sim
