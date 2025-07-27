using AutoMapper;
using gravi_application.DTOs;
using gravi_application.Mappings.Resolvers;
using gravi_domain.Entities;
using Microsoft.AspNetCore.Identity;
using Org.BouncyCastle.Crypto.Generators;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.Mappings
{
    public class UserProfile : Profile
    {
        public UserProfile()
        {
            CreateMap<AddUserDTO, User>()
                .ForMember(dest => dest.UserId, opt => opt.Ignore())
                .ForMember(dest => dest.Status, opt => opt.Ignore())
                .ForMember(dest => dest.IsEmailVerified, opt => opt.Ignore())
                .ForMember(dest => dest.Person, opt => opt.Ignore())
                .ForMember(dest => dest.PasswordHash, opt => opt.MapFrom<PasswordHashResolver>());

            CreateMap<User, UserDTO>()
                .ForMember(dest => dest.Status, opt => opt.MapFrom(src => (UserDTO.UserStatus)src.Status));

            CreateMap<UserDTO, User>()
                .ForMember(dest => dest.PasswordHash, opt => opt.Ignore());
        }
    }
}
