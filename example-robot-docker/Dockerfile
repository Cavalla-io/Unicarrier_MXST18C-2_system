ARG BASE_IMAGE
FROM ${BASE_IMAGE:-'ubuntu:20.04'}

RUN apt-get update && apt-get install -y iputils-ping curl git lsb-release gnupg vim

# a sudo user, for testing
RUN adduser -q --gecos "testuser" --disabled-password testuser
RUN addgroup testuser sudo
RUN echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# a normal user, for testing
RUN adduser -q --gecos "normaluser" --disabled-password normaluser

WORKDIR /root/.transitive
COPY config.json .

ARG USERID
ARG TOKEN
ENV USERID=${USERID}
ENV TOKEN=${TOKEN}
RUN curl -sf "https://install.transitiverobotics.com?id=$USERID&token=$TOKEN&docker=true" > /tmp/install.sh

# Install locales and set UTF-8 locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Set non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add the ROS 2 repository and key
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    echo "deb [arch=amd64,arm64] http://packages.ros.org/ros2/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros2-latest.list

# Install ROS 2 Foxy (minimal version; use ros-foxy-desktop if you need full GUI support)
RUN apt-get update && apt-get install -y \
    ros-foxy-ros-base \
    && rm -rf /var/lib/apt/lists/*

# (Optional) Automatically source ROS 2 Foxy setup in future shells
RUN echo "source /opt/ros/foxy/setup.bash" >> /root/.bashrc

# Install the agent
# RUN bash /tmp/install.sh
RUN chmod +x /tmp/install.sh

# If you want to pre-install capabilities that use ROS2, then you'll need to
# first source your ROS2 environment. Comment out the above line and use this
# instead (you may need to fill in the name of your ROS2 distro):
RUN bash -c ". /opt/ros/foxy/setup.bash && /tmp/install.sh"

WORKDIR /root
COPY entrypoint.sh .
CMD ["./entrypoint.sh"]
